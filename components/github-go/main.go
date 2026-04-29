// Go (TinyGo wasip2) implementation of the local:github component.
//
// TinyGo's net/http needs Go 1.24 stdlib features that 0.41 doesn't ship,
// so we drive wasi:http directly via the wit-bindgen-go generated bindings.
package main

import (
	"encoding/json"
	"fmt"

	"go.bytecodealliance.org/cm"

	apiexp "github-go/gen/local/github/api"
	outgoing "github-go/gen/wasi/http/outgoing-handler"
	httptypes "github-go/gen/wasi/http/types"
)

//go:generate wit-bindgen-go generate --world github --out gen ./wit

const userAgent = "github-wasm-go/0.1"

type ghUser struct {
	Login       string  `json:"login"`
	ID          uint64  `json:"id"`
	Name        *string `json:"name"`
	Bio         *string `json:"bio"`
	PublicRepos uint32  `json:"public_repos"`
	Followers   uint32  `json:"followers"`
	Following   uint32  `json:"following"`
	HTMLURL     string  `json:"html_url"`
}

type ghRepo struct {
	FullName        string  `json:"full_name"`
	Description     *string `json:"description"`
	StargazersCount uint32  `json:"stargazers_count"`
	ForksCount      uint32  `json:"forks_count"`
	Language        *string `json:"language"`
	DefaultBranch   string  `json:"default_branch"`
	HTMLURL         string  `json:"html_url"`
}

func ghGet(path string, token cm.Option[string]) ([]byte, error) {
	headers := httptypes.NewFields()
	if r := headers.Append("User-Agent", httptypes.FieldValue(cm.ToList([]byte(userAgent)))); r.IsErr() {
		return nil, fmt.Errorf("header: User-Agent")
	}
	if r := headers.Append("Accept", httptypes.FieldValue(cm.ToList([]byte("application/vnd.github+json")))); r.IsErr() {
		return nil, fmt.Errorf("header: Accept")
	}
	if t := token.Some(); t != nil {
		v := []byte("Bearer " + *t)
		if r := headers.Append("Authorization", httptypes.FieldValue(cm.ToList(v))); r.IsErr() {
			return nil, fmt.Errorf("header: Authorization")
		}
	}

	req := httptypes.NewOutgoingRequest(headers)
	req.SetMethod(httptypes.MethodGet())
	scheme := httptypes.SchemeHTTPS()
	req.SetScheme(cm.Some(scheme))
	req.SetAuthority(cm.Some("api.github.com"))
	req.SetPathWithQuery(cm.Some(path))

	fr := outgoing.Handle(req, cm.None[httptypes.RequestOptions]())
	if fr.IsErr() {
		return nil, fmt.Errorf("handle: %v", fr.Err())
	}
	future := *fr.OK()

	// Block until the response future resolves, then unwrap the
	// option<result<result<incoming-response, error-code>>>.
	var resp httptypes.IncomingResponse
	for {
		got := future.Get()
		if g := got.Some(); g != nil {
			if g.IsErr() {
				return nil, fmt.Errorf("future already taken: %v", g.Err())
			}
			inner := g.OK()
			if inner.IsErr() {
				return nil, fmt.Errorf("http: %v", inner.Err())
			}
			resp = *inner.OK()
			break
		}
		future.Subscribe().Block()
	}

	status := resp.Status()
	cons := resp.Consume()
	if cons.IsErr() {
		return nil, fmt.Errorf("consume body")
	}
	body := *cons.OK()
	streamRes := body.Stream()
	if streamRes.IsErr() {
		return nil, fmt.Errorf("body stream")
	}
	stream := *streamRes.OK()

	var buf []byte
	for {
		chunk := stream.BlockingRead(64 * 1024)
		if chunk.IsErr() {
			e := chunk.Err()
			if e.Closed() {
				break
			}
			return nil, fmt.Errorf("read: %v", e)
		}
		bytesRead := chunk.OK().Slice()
		buf = append(buf, bytesRead...)
	}

	if status < 200 || status >= 300 {
		snip := string(buf)
		if len(snip) > 200 {
			snip = snip[:200]
		}
		return nil, fmt.Errorf("HTTP %d: %s", status, snip)
	}
	return buf, nil
}

func optString(p *string) cm.Option[string] {
	if p == nil {
		return cm.None[string]()
	}
	return cm.Some(*p)
}

func init() {
	apiexp.Exports.GetUser = func(login string, token cm.Option[string]) cm.Result[apiexp.UserInfoShape, apiexp.UserInfo, string] {
		body, err := ghGet("/users/"+login, token)
		if err != nil {
			return cm.Err[cm.Result[apiexp.UserInfoShape, apiexp.UserInfo, string]](err.Error())
		}
		var u ghUser
		if err := json.Unmarshal(body, &u); err != nil {
			return cm.Err[cm.Result[apiexp.UserInfoShape, apiexp.UserInfo, string]]("parse: " + err.Error())
		}
		return cm.OK[cm.Result[apiexp.UserInfoShape, apiexp.UserInfo, string]](apiexp.UserInfo{
			Login:       u.Login,
			ID:          u.ID,
			Name:        optString(u.Name),
			Bio:         optString(u.Bio),
			PublicRepos: u.PublicRepos,
			Followers:   u.Followers,
			Following:   u.Following,
			HTMLURL:     u.HTMLURL,
		})
	}

	apiexp.Exports.GetRepo = func(owner, repo string, token cm.Option[string]) cm.Result[apiexp.RepoInfoShape, apiexp.RepoInfo, string] {
		body, err := ghGet("/repos/"+owner+"/"+repo, token)
		if err != nil {
			return cm.Err[cm.Result[apiexp.RepoInfoShape, apiexp.RepoInfo, string]](err.Error())
		}
		var r ghRepo
		if err := json.Unmarshal(body, &r); err != nil {
			return cm.Err[cm.Result[apiexp.RepoInfoShape, apiexp.RepoInfo, string]]("parse: " + err.Error())
		}
		return cm.OK[cm.Result[apiexp.RepoInfoShape, apiexp.RepoInfo, string]](apiexp.RepoInfo{
			FullName:        r.FullName,
			Description:     optString(r.Description),
			StargazersCount: r.StargazersCount,
			ForksCount:      r.ForksCount,
			Language:        optString(r.Language),
			DefaultBranch:   r.DefaultBranch,
			HTMLURL:         r.HTMLURL,
		})
	}
}

func main() {}
