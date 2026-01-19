// Generate bindings from WIT for the tech-ticker world.
wit_bindgen::generate!("tech-ticker");

use exports::component::tech_ticker::ticker::Guest;

struct Component;

impl Guest for Component {
    fn ping() -> String {
        "tech-ticker ready".to_string()
    }
}

export!(Component);
