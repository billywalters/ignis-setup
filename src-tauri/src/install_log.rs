// src-tauri/src/install_log.rs — persistent install log
use crate::types::{CommandResult, dirs_home};

fn install_log_path() -> std::path::PathBuf {
    let home = dirs_home().unwrap_or_else(|| "/tmp".to_string());
    std::path::PathBuf::from(format!("{}/.local/share/ignis-setup/install-log.json", home))
}

#[tauri::command]
pub fn read_install_log() -> CommandResult {
    let path = install_log_path();
    match std::fs::read_to_string(&path) {
        Ok(content) => CommandResult::ok(content),
        Err(_)      => CommandResult::ok("{}".to_string()),
    }
}

#[tauri::command]
pub fn write_install_log(content: String) -> CommandResult {
    let path = install_log_path();
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).ok();
    }
    match std::fs::write(&path, content) {
        Ok(_)  => CommandResult::ok("written".to_string()),
        Err(e) => CommandResult::err(format!("Failed to write install log: {}", e)),
    }
}
