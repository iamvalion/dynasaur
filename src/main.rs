use paris::{formatter::colorize_string, Logger};
use simplelog::__private::paris;

fn main() {
    let mut plog = Logger::new();

    println!("{}", colorize_string("<green>DYNASAUR</>"));
    plog.info("Running...");

    /*
    TODO
    Actions & Components
    - Parse environment variables (env)
    - Parse settings file (toml)
    - Parse records file (serde_json)
    - Parse command line args (clap)
    - Send request to GET Cloudflare token status (reqwest)
    - Run checks
        - Send request for public IP (process:Command - dig | curl | nslookup)
        - Send request to GET active Cloudflare DNS record IP (reqwest)
        - Send request to POST active Cloudflare DNS record IP (reqwest)
    - Log results throughout the process (simplelog & paris)
     */
}