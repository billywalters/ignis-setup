// src/lib/network.js
// Network input validation helpers used by the static IP form.
// Kept separate from tauri.js (which holds IPC bindings) so validation
// logic can be unit-tested independently of the Tauri runtime.

const CIDR_RE = /^(\d{1,3}\.){3}\d{1,3}\/(8|16|24|25|26|27|28|29|30|31|32)$/;
const IP_RE   = /^(\d{1,3}\.){3}\d{1,3}$/;
const DNS_RE  = /^((\d{1,3}\.){3}\d{1,3})(,(\d{1,3}\.){3}\d{1,3})*$/;

/** Validates an IPv4 address with CIDR prefix, e.g. 192.168.1.50/24 */
export function validateIpCidr(ip) {
  return CIDR_RE.test(ip.trim());
}

/** Validates a plain IPv4 address, e.g. 192.168.1.1 */
export function validateIp(ip) {
  return IP_RE.test(ip.trim());
}

/** Validates one or more comma-separated IPv4 DNS addresses */
export function validateDns(dns) {
  return DNS_RE.test(dns.trim());
}

/** Returns a human-readable error string, or null if valid */
export function ipCidrError(ip) {
  return validateIpCidr(ip) ? null : "Must be in CIDR format, e.g. 192.168.1.50/24";
}

export function ipError(ip) {
  return validateIp(ip) ? null : "Must be a valid IPv4 address, e.g. 192.168.1.1";
}

export function dnsError(dns) {
  return validateDns(dns) ? null : "Comma-separated IPv4 addresses, e.g. 1.1.1.1,8.8.8.8";
}
