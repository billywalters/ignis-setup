// src-tauri/src/ge_proton.rs — GE-Proton installation and Steam default management
use serde::{Deserialize, Serialize};
use crate::types::{CommandResult, run_cmd, host_command};

#[derive(Serialize, Deserialize, Debug)]
pub struct GeProtonStatus {
    pub installed_version: Option<String>,
    pub steam_default:     Option<String>,
    pub is_default:        bool,
    pub steam_root:        Option<String>,
}

pub fn find_steam_root() -> Option<String> {
    let home = std::env::var("HOME").ok()?;
    let native  = format!("{}/.steam/steam", home);
    let flatpak = format!("{}/.var/app/com.valvesoftware.Steam/data/Steam", home);
    if std::path::Path::new(&format!("{}/config/config.vdf", native)).exists() {
        return Some(native);
    }
    if std::path::Path::new(&format!("{}/config/config.vdf", flatpak)).exists() {
        return Some(flatpak);
    }
    None
}

/// Minimal VDF parser — extracts the "name" value from the "0" block in CompatToolMapping
fn parse_compat_tool_default(content: &str) -> Option<String> {
    let start      = content.find("\"CompatToolMapping\"")?;
    let block      = &content[start..];
    let zero_start = block.find("\"0\"")?;
    let zero_block = &block[zero_start..];
    let brace_open = zero_block.find('{')?;
    let inner      = &zero_block[brace_open..];
    let brace_close= inner.find('}')?;
    let inner      = &inner[..brace_close];
    let name_pos   = inner.find("\"name\"")?;
    let after_name = &inner[name_pos + 6..];
    let q1         = after_name.find('"')? + 1;
    let rest       = &after_name[q1..];
    let q2         = rest.find('"')?;
    let name       = &rest[..q2];
    if name.is_empty() { None } else { Some(name.to_string()) }
}

#[tauri::command]
pub fn ge_proton_status() -> GeProtonStatus {
    let steam_root = find_steam_root();

    let installed_version = steam_root.as_ref().and_then(|root| {
        let compat_dir = format!("{}/compatibilitytools.d", root);
        std::fs::read_dir(&compat_dir).ok().and_then(|entries| {
            let mut versions: Vec<String> = entries
                .filter_map(|e| e.ok())
                .filter_map(|e| {
                    let name = e.file_name().into_string().ok()?;
                    if name.starts_with("GE-Proton") { Some(name) } else { None }
                })
                .collect();
            versions.sort();
            versions.pop()
        })
    });

    let steam_default = steam_root.as_ref().and_then(|root| {
        let config_path = format!("{}/config/config.vdf", root);
        let content = std::fs::read_to_string(&config_path).ok()?;
        parse_compat_tool_default(&content)
    });

    let is_default = match (&installed_version, &steam_default) {
        (Some(iv), Some(sd)) => iv == sd,
        _ => false,
    };

    GeProtonStatus { installed_version, steam_default, is_default, steam_root }
}

#[tauri::command]
pub fn install_ge_proton(script_dir: String) -> CommandResult {
    let script = format!("{}/setup-ge-proton.sh", script_dir);
    if !std::path::Path::new(&script).exists() {
        return CommandResult::err(format!("Script not found: {}", script));
    }
    run_cmd("bash", &[&script])
}

#[tauri::command]
pub fn set_ge_proton_default(ge_version: String) -> CommandResult {
    if ge_version.is_empty() {
        return CommandResult::err("ge_version cannot be empty".into());
    }

    let steam_running = host_command("pgrep").args(["-x", "steam"]).output()
        .map(|o| o.status.success()).unwrap_or(false);
    if steam_running {
        return CommandResult::err("Steam is running. Close it before changing the default Proton.".into());
    }

    let root = match find_steam_root() {
        Some(r) => r,
        None => return CommandResult::err("Steam installation not found.".into()),
    };
    let config_path = format!("{}/config/config.vdf", root);

    let py_script = format!(
        r#"
import sys, re
config_path = r'{config}'
ge_name = r'{name}'
with open(config_path, 'r', encoding='utf-8') as f:
    content = f.read()
new_entry = '\n\t\t\t"0"\n\t\t\t{{\n\t\t\t\t"name"\t\t"' + ge_name + '"\n\t\t\t\t"config"\t\t""\n\t\t\t\t"Priority"\t\t"250"\n\t\t\t}}'
compat_re = re.compile(r'("CompatToolMapping"\s*\{{)(.*?)(\n(\s*)\}})', re.DOTALL)
def update(m):
    body = re.sub(r'\s*"0"\s*\{{[^{{}}]*\}}', '', m.group(2), flags=re.DOTALL)
    return m.group(1) + new_entry + body + m.group(3)
new_content = compat_re.sub(update, content, count=1)
with open(config_path, 'w', encoding='utf-8') as f:
    f.write(new_content)
print('OK')
"#,
        config = config_path,
        name   = ge_version,
    );

    let tmp_py = "/tmp/bm_ge_set_default.py";
    if std::fs::write(tmp_py, py_script).is_err() {
        return CommandResult::err("Failed to write temp Python script".into());
    }
    let result = run_cmd("python3", &[tmp_py]);

    // Bazzite steamdeck-flag fix
    let home = std::env::var("HOME").unwrap_or_default();
    let flag_dir  = format!("{}/.config/bazzite", home);
    let flag_file = format!("{}/disable_steamdeck_flag", flag_dir);
    std::fs::create_dir_all(&flag_dir).ok();
    if !std::path::Path::new(&flag_file).exists() {
        std::fs::write(&flag_file, "").ok();
    }

    result
}

#[tauri::command]
pub fn is_steam_running() -> bool {
    for name in &["steam", "steam.sh", "steamwebhelper"] {
        if host_command("pgrep").args(["-x", name]).output()
            .map(|o| o.status.success()).unwrap_or(false) {
            return true;
        }
    }
    false
}
