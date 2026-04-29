wit_bindgen::generate!({
    world: "wasip3-demo",
    path: "wit",
    async: ["greet-async"],
});

struct Component;

impl Guest for Component {
    fn greet(name: String) -> String {
        format!("Hello sync, {name}!")
    }

    async fn greet_async(name: String) -> String {
        format!("Hello async, {name}!")
    }
}

export!(Component);
