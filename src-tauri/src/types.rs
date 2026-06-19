// src-tauri/src/types.rs — shared types used across all modules
use serde::{Deserialize, Serialize};
use std::process::Command;

#[derive(Serialize, Deserialize, Debug)]
pub struct CommandResult {
    pub success:   bool,
    pub stdout:    String,
    pub stderr:    String,
    pub exit_code: i32,
}

impl CommandResult {
    pub fn ok(stdout: String) -> Self {
        CommandResult { success: true, stdout, stderr: String::new(), exit_code: 0 }
    }
    pub fn err(stderr: String) -> Self {
        CommandResult { success: false, stdout: String::new(), stderr, exit_code: 1 }
    }
}

pub fn run_cmd(cmd: &str, args: &[&str]) -> CommandResult {
    match Command::new(cmd).args(args).output() {
        Ok(out) => CommandResult {
            success:   out.status.success(),
            stdout:    String::from_utf8_lossy(&out.stdout).to_string(),
            stderr:    String::from_utf8_lossy(&out.stderr).to_string(),
            exit_code: out.status.code().unwrap_or(-1),
        },
        Err(e) => CommandResult::err(format!("Failed to run '{}': {}", cmd, e)),
    }
}

pub fn run_sudo_cmd(cmd: &str, args: &[&str]) -> CommandResult {
    let mut full_args = vec![cmd];
    full_args.extend_from_slice(args);
    match Command::new("pkexec").args(&full_args).output() {
        Ok(out) => CommandResult {
            success:   out.status.success(),
            stdout:    String::from_utf8_lossy(&out.stdout).to_string(),
            stderr:    String::from_utf8_lossy(&out.stderr).to_string(),
            exit_code: out.status.code().unwrap_or(-1),
        },
        Err(e) => CommandResult::err(format!("pkexec failed: {}", e)),
    }
}

pub fn dirs_home() -> Option<String> {
    std::env::var("HOME").ok()
}
