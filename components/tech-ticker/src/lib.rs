// Generate bindings from WIT for the tech-ticker world.
wit_bindgen::generate!("tech-ticker");

use exports::component::tech_ticker::ticker::Guest;

struct Component;

impl Guest for Component {
    fn ping() -> String {
        "tech-ticker ready".to_string()
    }

    fn random_string(length: u32) -> String {
        const CHARSET: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
        let mut result = String::with_capacity(length as usize);
        
        // Simple LCG random number generator seeded from wall clock
        let seed = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_nanos() as u64)
            .unwrap_or(12345);
        
        let mut rng = seed;
        for _ in 0..length {
            // LCG: next = (a * current + c) mod m
            rng = rng.wrapping_mul(6364136223846793005).wrapping_add(1);
            let idx = ((rng >> 33) as usize) % CHARSET.len();
            result.push(CHARSET[idx] as char);
        }
        
        result
    }
}

export!(Component);
