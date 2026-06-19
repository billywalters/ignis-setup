// src-tauri/src/network.rs — network, NAS, and static IP commands
use crate::types::{CommandResult, run_cmd, run_sudo_cmd};

#[tauri::command]
pub fn list_network_interfaces() -> CommandResult {
    run_cmd("nmcli", &["-t", "-f", "DEVICE,CONNECTION,IP4.ADDRESS,STATE", "device", "show"])
}

#[tauri::command]
pub fn list_connections() -> CommandResult {
    run_cmd("nmcli", &["-t", "-f", "NAME,UUID,TYPE,DEVICE", "connection", "show"])
}

#[tauri::command]
pub fn set_static_ip(connection: String, ip_cidr: String, gateway: String, dns: String) -> CommandResult {
    let r = run_cmd("nmcli", &[
        "connection", "modify", &connection,
        "ipv4.method",    "manual",
        "ipv4.addresses", &ip_cidr,
        "ipv4.gateway",   &gateway,
        "ipv4.dns",       &dns,
        "connection.autoconnect", "yes",
    ]);
    if !r.success { return r; }
    run_cmd("nmcli", &["connection", "up", &connection])
}

#[tauri::command]
pub fn set_dhcp(connection: String) -> CommandResult {
    let r = run_cmd("nmcli", &[
        "connection", "modify", &connection,
        "ipv4.method",    "auto",
        "ipv4.addresses", "",
        "ipv4.gateway",   "",
        "ipv4.dns",       "",
    ]);
    if !r.success { return r; }
    run_cmd("nmcli", &["connection", "up", &connection])
}

#[tauri::command]
pub fn mount_nas_share(
    server: String, share: String, mount_pt: String,
    username: String, password: String, protocol: String,
) -> CommandResult {
    let _ = std::fs::create_dir_all(&mount_pt);
    if protocol == "nfs" {
        run_sudo_cmd("mount", &["-t", "nfs", &format!("{}:{}", server, share), &mount_pt])
    } else {
        let opts = if username.is_empty() {
            "guest,uid=1000,gid=1000".to_string()
        } else {
            format!("username={},password={},uid=1000,gid=1000", username, password)
        };
        run_sudo_cmd("mount", &["-t", "cifs", &format!("//{}/{}", server, share), &mount_pt, "-o", &opts])
    }
}

#[tauri::command]
pub fn add_fstab_entry(server: String, share: String, mount_pt: String, username: String, protocol: String) -> CommandResult {
    let entry = if protocol == "nfs" {
        format!("{}:{}  {}  nfs  defaults,_netdev  0  0\n", server, share, mount_pt)
    } else {
        let creds = if username.is_empty() {
            "guest".to_string()
        } else {
            format!("credentials=/etc/samba/credentials_{}", share.replace('/', "_"))
        };
        format!("//{}/{}  {}  cifs  {},_netdev,uid=1000,gid=1000  0  0\n", server, share, mount_pt, creds)
    };
    let tmp = "/tmp/bazzite_fstab_entry.txt";
    std::fs::write(tmp, &entry).ok();
    run_sudo_cmd("bash", &["-c", &format!("cat {} >> /etc/fstab", tmp)])
}

#[tauri::command]
pub fn test_nas_connection(server: String) -> CommandResult {
    run_cmd("ping", &["-c", "1", "-W", "2", &server])
}
