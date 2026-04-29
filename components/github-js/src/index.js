// JavaScript implementation of the local:github component.
//
// jco / componentize-js maps `fetch` to wasi:http/outgoing-handler.
// Authentication is per-call via an optional bearer token.

const USER_AGENT = "github-wasm-js/0.1";

async function ghGet(path, token) {
    const headers = {
        "User-Agent": USER_AGENT,
        "Accept": "application/vnd.github+json",
    };
    if (token) headers["Authorization"] = `Bearer ${token}`;
    const res = await fetch(`https://api.github.com${path}`, { headers });
    if (!res.ok) {
        const body = await res.text();
        throw new Error(`HTTP ${res.status}: ${body.slice(0, 200)}`);
    }
    return res.json();
}

export const api = {
    async getUser(login, token) {
        const u = await ghGet(`/users/${encodeURIComponent(login)}`, token);
        return {
            login: String(u.login),
            id: BigInt(u.id),
            name: u.name == null ? undefined : String(u.name),
            bio: u.bio == null ? undefined : String(u.bio),
            publicRepos: Number(u.public_repos),
            followers: Number(u.followers),
            following: Number(u.following),
            htmlUrl: String(u.html_url),
        };
    },

    async getRepo(owner, repo, token) {
        const r = await ghGet(
            `/repos/${encodeURIComponent(owner)}/${encodeURIComponent(repo)}`,
            token,
        );
        return {
            fullName: String(r.full_name),
            description: r.description == null ? undefined : String(r.description),
            stargazersCount: Number(r.stargazers_count),
            forksCount: Number(r.forks_count),
            language: r.language == null ? undefined : String(r.language),
            defaultBranch: String(r.default_branch),
            htmlUrl: String(r.html_url),
        };
    },
};
