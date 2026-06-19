// src-tauri/src/jellyfin.rs — Jellyfin Podman Quadlet management
use crate::types::{CommandResult, run_cmd, run_sudo_cmd, dirs_home};

#[tauri::command]
pub fn install_jellyfin(media_path: String) -> CommandResult {
    let home = dirs_home().unwrap_or_else(|| "/tmp".to_string());
    let quadlet_dir = format!("{}/.config/containers/systemd", home);
    let config_vol  = format!("{}/.local/share/jellyfin/config", home);
    let cache_vol   = format!("{}/.local/share/jellyfin/cache", home);

    std::fs::create_dir_all(&quadlet_dir).ok();
    std::fs::create_dir_all(&config_vol).ok();
    std::fs::create_dir_all(&cache_vol).ok();

    let quadlet = format!(
r#"# Ignis — Jellyfin Quadlet
[Unit]
Description=Jellyfin Media Server
After=network-online.target
Wants=network-online.target

[Container]
Image=docker.io/jellyfin/jellyfin:latest
ContainerName=jellyfin
PublishPort=8096:8096
PublishPort=8920:8920
Volume={}:/config
Volume={}:/cache
Volume={}:/media:ro
Environment=JELLYFIN_PublishedServerUrl=http://localhost:8096
Label=io.containers.autoupdate=registry

[Service]
Restart=always
TimeoutStartSec=120

[Install]
WantedBy=default.target
"#,
        config_vol, cache_vol, media_path
    );

    let unit_path = format!("{}/jellyfin.container", quadlet_dir);
    if let Err(e) = std::fs::write(&unit_path, quadlet) {
        return CommandResult::err(format!("Failed to write quadlet: {}", e));
    }

    let r = run_cmd("systemctl", &["--user", "daemon-reload"]);
    if !r.success { return r; }

    let username = std::env::var("USER").unwrap_or_default();
    let _ = run_sudo_cmd("loginctl", &["enable-linger", &username]);

    let r2 = run_cmd("systemctl", &["--user", "enable", "--now", "jellyfin"]);
    if !r2.success { return r2; }

    CommandResult::ok(format!(
        "Jellyfin installed and started.\nUnit: {}\nDashboard: http://localhost:8096",
        unit_path
    ))
}

#[tauri::command]
pub fn jellyfin_status()  -> CommandResult { run_cmd("systemctl", &["--user", "is-active", "jellyfin"]) }
#[tauri::command]
pub fn jellyfin_start()   -> CommandResult { run_cmd("systemctl", &["--user", "start",     "jellyfin"]) }
#[tauri::command]
pub fn jellyfin_stop()    -> CommandResult { run_cmd("systemctl", &["--user", "stop",      "jellyfin"]) }
#[tauri::command]
pub fn jellyfin_restart() -> CommandResult { run_cmd("systemctl", &["--user", "restart",   "jellyfin"]) }
