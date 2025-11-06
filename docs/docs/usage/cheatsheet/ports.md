---
title: "Cheatsheet › Ports List"
tags:
  - cheatsheet
  - configure
  - configs
  - resource
  - ports
---

# Cheatsheet: Port List <!-- omit from toc -->

The following list of ports can be referenced when setting up CSF firewall with your other applications:

| Port   | TCP | UDP | Description |
| ------ | --- | --- | ----------- |
| `20`     | ✅  | ✅  | FTP Data (mostly TCP, rarely UDP) |
| `21`     | ✅  | ✅  | FTP Control (mostly TCP, rarely UDP) |
| `22`     | ✅  |     | SSH [^1] / SCP / SFTP |
| `23`     | ✅  |     | Telnet |
| `25`     | ✅  |     | SMTP (non-secure email sending) |
| `26`     | ✅  |     | SMTP (non-secure email sending, alternate when 25 blocked) |
| `37`     | ✅  | ✅  | Machine-readable time protocol (rdate) |
| `43`     | ✅  |     | Whois |
| `53`     | ✅  | ✅  | DNS (Pihole, AdGuard) |
| `67`     |     | ✅  | DHCP Server  | Pihole  DHCP |
| `68`     |     | ✅  | DHCP Client |
| `69`     |     | ✅  | TFTP (Trivial File Transfer Protocol) |
| `70`     | ✅  |     | Gopher |
| `71`     | ✅  |     | Genius protocol |
| `80`     | ✅  | ✅  | HTTP (web traffic) |
| `88`     | ✅  | ✅  | Kerberos authentication |
| `110`    | ✅  |     | POP3 (non-secure email retrieval) |
| `113`    | ✅  | ✅  | Identification Protocol (Ident) (RFC 1413) |
| `123`    |     | ✅  | NTP (Network Time Protocol) / Pihole |
| `137`    |     | ✅  | NetBIOS Name Service (Samba name resolution) |
| `138`    |     | ✅  | NetBIOS Datagram Service (Samba broadcasts) |
| `139`    | ✅  |     | NetBIOS Session Service (Samba file/printer sharing) |
| `143`    | ✅  |     | IMAP (non-secure email retrieval) |
| `443`    | ✅  | ✅  | HTTPS / QUIC / DoH (DNS over HTTPS, HTTP/3) |
| `445`    | ✅  | ✅  | Microsoft-DS / SMB over TCP/IP (Samba) |
| `458`    |     |      | Apple QuickTime / Real-Time Streaming Protocol (RTSP) |
| `465`    | ✅  |     | SMTPS (secure SMTP) |
| `546`    |     | ✅  | DHCPv6 Client | 
| `547`    |     | ✅  | DHCPv6 Server (Pihole, etc) |
| `565`    | ✅  | ✅  | Whoami |
| `566`    | ✅  | ✅  | Streettalk |
| `587`    | ✅  |     | SMTP submission |
| `574`    | ✅  | ✅  | FTP Software Agent System |
| `596`    | ✅  | ✅  | SysMan Station daemon |
| `783`    | ✅  |     | [Spamassassin](https://spamassassin.apache.org/) Razor Agent | 
| `853`    | ✅  | ✅  | DNS over TLS (DoT) |
| `873`    | ✅  |     | Rsync file transfer |
| `953`    | ✅  |     | Unbound Remote control / statistics (RPC for unbound-control) | 
| `993`    | ✅  |     | IMAPS (secure IMAP) |
| `995`    | ✅  |     | POP3S (secure POP3) |
| `1025`   | ✅  |     | Microsoft Remote Procedure Call |
| `1194`   | ✅  | ✅ | [OpenVPN](https://openvpn.net/) |
| `1241`   | ✅  | ✅  | [Nessus](https://www.tenable.com/products/nessus) security scanner |
| `1311`   | ✅  |     | Dell OpenManage server administrator web GUI (EMC) |
| `1337`   | ✅  |     | WASTE peer-to-peer encrypted file-sharing Program |
| `1589`   | ✅  | ✅  | Cisco VLAN Query Protocol (VQP) | 
| `1701`   | ✅  |     | Layer Two Tunneling Protocol Virtual Private Networking | 
| `1723`   | ✅  | ✅ | Microsoft PPTP | 
| `1725`   |     | ✅  | [Steam](https://store.steampowered.com/about/) Client | 
| `1863`   | ✅  |    | [MSN Live Messenger](https://escargot.chat/download/), Xbox Live 360 | 
| `1900`   |     | ✅  | Universal Plug and Play (UPnP) | 
| `2049`   | ✅  | ✅  | Network File Sharing (NFS) | 
| `2077`   | ✅  |     | [cPanel](https://cpanel.net/) Web Disk (HTTPS) / WebDAV |
| `2078`   | ✅  |     | Web Disk (HTTP) / WebDAV |
| `2079`   | ✅  |     | Web Disk (HTTPS) / CalDAV |
| `2080`   | ✅  |     | Web Disk (HTTP) |
| `2082`   | ✅  |     | [cPanel](https://cpanel.net/) (HTTP) / [CWP](https://control-webpanel.com/) User Panel (HTTP) |
| `2083`   | ✅  |     | [cPanel](https://cpanel.net/) (HTTPS) / [CWP](https://control-webpanel.com/) User Panel (HTTPS) |
| `2086`   | ✅  |     | [WHM](https://cpanel.net/) (HTTP) / [CWP](https://control-webpanel.com/) Admin (HTTP) |
| `2087`   | ✅  |     | [WHM](https://cpanel.net/) (HTTPS) / [CWP](https://control-webpanel.com/) Admin (HTTPS) / Event Logging Integration (ELI) |
| `2095`   | ✅  |     | Webmail (HTTP) |
| `2096`   | ✅  |     | Webmail (HTTPS) |
| `2089`   | ✅  |     | [cPanel](https://cpanel.net/) Licensing |
| `2091`   | ✅  |     | ActiveSync | 
| `2222`   | ✅  |     | [DirectAdmin](https://directadmin.com/) control panel |
| `2304`   | ✅  |     | [CWP](https://control-webpanel.com/) External API SSL (HTTPS for API access) |
| `2703`   | ✅  |     | Local [Spamassassin](https://spamassassin.apache.org/) / CSF+LFD  |
| `3000`   | ✅  |     | [Gogs](https://gogs.io/) 🔹 [Gitea](https://about.gitea.com/) 🔹 [Grafana](https://grafana.com/) 🔹 [Jellyfin Stats ](https://github.com/CyferShepard/Jellystat) 🔹 [Linkwarden](https://linkwarden.app/) 🔹 [Obsidian LiveSync](https://github.com/vrtmrz/obsidian-livesync) 🔹 [Slink](https://github.com/andrii-kryvoviaz/slink) / [Zipline](https://github.com/diced/zipline) |
| `3001`   | ✅  |     | [Uptime Kuma](https://github.com/louislam/uptime-kuma) / [Obsidian](https://hub.docker.com/r/linuxserver/obsidian) |
| `3306`   | ✅  |     | [MySQL](https://hub.docker.com/_/mysql) / [MariaDB](https://hub.docker.com/_/mariadb) |
| `3389`   | ✅  |     | Remote Desktop Protocol (RDP) |
| `3875`   | ✅  |     | [Duplicacy](https://hub.docker.com/r/saspus/duplicacy-web) |
| `5001`   | ✅  |     | [Dockge](https://github.com/louislam/dockge) |
| `5224`   | ✅  |     | [Plesk](https://plesk.com/) license check |
| `5432`   | ✅  |     | [Postgres](https://hub.docker.com/_/postgres) |
| `5601`   | ✅  |     | [Kibana](https://elastic.co/kibana) web interface 🔹 visualization/dashboard for [Elastic Search](https://elastic.co/downloads/elasticsearch) (HTTP) |
| `5938`   | ✅  |     | [Teamviewer](https://teamviewer.com/en-us/download/windows/) |
| `5984 `  | ✅  |     | [CouchDB](https://hub.docker.com/_/couchdb) Clustered Mode |
| `6077`   | ✅  |     | [Cabernet](https://github.com/cabernetwork/cabernet) |
| `6157`   | ✅  |     | [Opengist](https://github.com/thomiceli/opengist) |
| `6277`   | ✅  | ✅  | [CSF / LFD](https://github.com/orgs/Revolutionary-Technology-Company/) internal service |
| `6379`   | ✅  |     | [Redis](https://hub.docker.com/_/redis) |
| `6568`   | ✅  | ✅  | [AnyDesk](https://anydesk.com) streaming (peer-to-peer connections) |
| `6881`   | ✅  | ✅  | [qBittorrent](https://hub.docker.com/r/linuxserver/qbittorrent) |
| `6666`   | ✅  |     | [CSF / LFD](https://github.com/orgs/Revolutionary-Technology-Company/) web interface |
| `7080`   | ✅  |     | [LiteSpeed WebAdmin Console](https://litespeedtech.com/) | 
| `8083`   | ✅  |     | [VestaCP](https://vestacp.com/) control panel |
| `8096`   | ✅  |     | [Jellyfin](https://github.com/jellyfin/jellyfin) |
| `8200`   | ✅  |     | [Hashicorp](https://github.com/hashicorp/vault) Vault 🔹 [Duplicati](https://github.com/duplicati/duplicati) control panel |
| `8384`   | ✅  |     | [Syncthing](https://syncthing.net/) |
| `8443`   | ✅  |     | [Plesk](https://plesk.com/) administrative interface (HTTPS) |
| `8840`   | ✅  | ✅  | [WatchYourLan](https://github.com/aceberg/WatchYourLAN) |
| `8880`   | ✅  |     | [Plesk administrative interface (HTTP)](https://plesk.com/) / [Vuetorrent](https://github.com/VueTorrent/VueTorrent) |
| `8853`   | ✅  | ✅  | [WatchYourPorts](https://github.com/aceberg/WatchYourPorts) |
| `9000`   | ✅  |     | [Portainer](https://portainer.io/) (HTTP) |
| `9001`   | ✅  |     | [Portainer agent](https://hub.docker.com/r/portainer/agent) |
| `9090`   | ✅  |     | [Prometheus](https://prometheus.io/download/) |
| `9100`   | ✅  |     | [Prometheus](https://prometheus.io/download/) Node Exporter |
| `9200`   | ✅  |     | [Elastic Search](https://elastic.co/downloads/elasticsearch) REST API |
| `9300`   | ✅  |     | [Elastic Search](https://elastic.co/downloads/elasticsearch) internal cluster communication |
| `9443`   | ✅  |     | [Portainer](https://portainer.io/) (HTTPS) |
| `9600`   | ✅  |     | [Elastic Search](https://elastic.co/downloads/elasticsearch) monitoring API (used by X-Pack/[Elastic Search](https://elastic.co/downloads/elasticsearch) stack monitoring) |
| `9999`   | ✅  |     | [Stash](https://github.com/stashapp/stash) |
| `10000`  | ✅  |     | [Webmin](https://webmin.com/) control panel |
| `11211`  | ✅  | ✅  | [Memcached](https://memcached.org) |
| `22067`  | ✅  |     | [Syncthing](https://syncthing.net/) Relay Server |
| `22070`  | ✅  |     | [Syncthing](https://syncthing.net/) Relay Server |
| `22000`  | ✅  |     | [Syncthing](https://syncthing.net/) Relay Server |
| `27017`  | ✅  |     | [MongoDB](https://mongodb.com/try/download/community) |
| `24441`  | ✅  | ✅  | [CSF / LFD](https://github.com/orgs/Revolutionary-Technology-Company/) internal services / [Spamassassin](https://spamassassin.apache.org/) Pyzor |
| `32400`  | ✅  |     | [Plesk](https://plesk.com/) |
| `34400`  | ✅  |     | [Threadfin](https://github.com/Threadfin/Threadfin) |
| `50001`  |     | ✅   | [AnyDesk](https://anydesk.com) Discovery - Identify devices on the local network |
| `50002`  |     | ✅   | [AnyDesk](https://anydesk.com) Discovery - Identify devices on the local network |
| `50003`  |     | ✅   | [AnyDesk](https://anydesk.com) Discovery - Identify devices on the local network |

[^1]: Some sources list UDP for port 22, but officially SSH only uses TCP. UDP is not standard for this service.

<br />
<br />
