// src-tauri/src/lib.rs
// Thin orchestrator: declares modules and wires all Tauri commands.
// Business logic lives in the individual module files.

pub mod types;
pub mod system;
pub mod installs;
pub mod network;
pub mod jellyfin;
pub mod ge_proton;
pub mod install_log;

use installs::*;
use network::*;
use jellyfin::*;
use ge_proton::*;
use install_log::*;
use system::get_system_info;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![
            // System
            get_system_info,
            // App installs — generic
            install_flatpak_app,
            check_flatpak_installed,
            run_ujust,
            run_bash_script,
            run_bash_script_with_args,
            check_command_exists,
            // App installs — OS-specific
            install_pacman_pkg,
            install_aur_pkg,
            install_rpm_ostree_pkg,
            install_apt_pkg,
            // Network
            list_network_interfaces,
            list_connections,
            set_static_ip,
            set_dhcp,
            mount_nas_share,
            add_fstab_entry,
            test_nas_connection,
            // Jellyfin
            install_jellyfin,
            jellyfin_status,
            jellyfin_start,
            jellyfin_stop,
            jellyfin_restart,
            // GE-Proton
            ge_proton_status,
            install_ge_proton,
            set_ge_proton_default,
            is_steam_running,
            // Install log
            read_install_log,
            write_install_log,
        ])
        .run(tauri::generate_context!())
        .expect("error while running Ignis");
}
