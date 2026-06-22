#!/usr/bin/env python3
"""
Generates the DETAILED architecture + data-flow diagram (architecture-detailed.svg):
all internal components of each control plane, the endpoint agents, and the
protocol/port on every link. Companion to docs/architecture.md.

Run: python3 docs/diagrams/build_architecture_detailed.py
"""
import html, os
HERE = os.path.dirname(__file__)

NAVY="#0B2545"; BLUE="#1B6CA8"; TEAL="#13A89E"; AMBER="#C8841F"; GREEN="#2E8B57"
PURPLE="#6C4AB6"; GRAY="#5A6B7B"; LIGHT="#F2F5F8"; WHITE="#FFFFFF"; RED="#C0392B"
INK="#0B2545"; FAINT="#E7EDF3"
F='font-family="Helvetica, Arial, sans-serif"'

def esc(s): return html.escape(str(s))
def rect(x,y,w,h,fill=WHITE,stroke="none",rx=8,sw=1.5,op=1):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" ry="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" fill-opacity="{op}"/>'
def txt(x,y,s,size=12,color=INK,weight="normal",anchor="middle",style=""):
    return f'<text x="{x}" y="{y}" font-size="{size}" fill="{color}" font-weight="{weight}" text-anchor="{anchor}" {style}>{esc(s)}</text>'
def zone(x,y,w,h,title,stroke):
    o=[rect(x,y,w,h,LIGHT,stroke,rx=14,sw=2,op=0.6)]
    o.append(f'<rect x="{x}" y="{y}" width="{w}" height="26" rx="14" fill="{stroke}"/>')
    o.append(f'<rect x="{x}" y="{y+13}" width="{w}" height="13" fill="{stroke}"/>')
    o.append(txt(x+14,y+18,title,13,WHITE,"bold","start"))
    return "".join(o)
def chip(x,y,w,h,title,subs=None,accent=BLUE,tsize=12.5):
    o=[rect(x,y,w,h,WHITE,accent,rx=8,sw=1.6), f'<rect x="{x}" y="{y}" width="{w}" height="5" rx="2" fill="{accent}"/>']
    o.append(txt(x+w/2,y+22,title,tsize,NAVY,"bold"))
    for i,s in enumerate(subs or []):
        o.append(txt(x+w/2,y+40+i*15,s,10,GRAY))
    return "".join(o)
def arrow(x1,y1,x2,y2,color=GRAY,label="",dash=False,w=2,loff=0,lsize=10):
    d=f' stroke-dasharray="5 4"' if dash else ""
    o=[f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="{w}" marker-end="url(#ah)"{d}/>']
    if label:
        mx,my=(x1+x2)/2,(y1+y2)/2-4+loff
        tw=len(label)*lsize*0.55
        o.append(rect(mx-tw/2,my-lsize-2,tw,lsize+8,WHITE,"none",rx=3,sw=0))
        o.append(txt(mx,my,label,lsize,color,"bold"))
    return "".join(o)

DEFS=f'''<defs>
 <marker id="ah" markerWidth="9" markerHeight="8" refX="8" refY="3" orient="auto" markerUnits="strokeWidth">
   <path d="M0,0 L8,3 L0,6 Z" fill="{GRAY}"/></marker>
</defs>'''

P=[]
P.append(rect(0,0,1480,980,WHITE,"none",rx=0,sw=0))
P.append(txt(740,34,"Open Endpoint Management — Detailed Architecture & Data Flow",20,NAVY,"bold"))
P.append(txt(740,54,"Assemble-first: Tactical RMM (remediation) + FleetDM (compliance) · agents phone home outbound 443 · control planes managed via AWS SSM",11.5,GRAY))

# ---------- ENDPOINT zone ----------
P.append(zone(24,70,320,592,"WINDOWS 10/11 ENDPOINT  (agents run as SYSTEM)",BLUE))
P.append(chip(44,108,280,86,"Tactical RMM Agent",["Go service · check-in, run scripts,","apply patches, install software"],BLUE))
P.append(chip(44,206,280,58,"Mesh Agent (MeshCentral)",["remote desktop / shell"],PURPLE))
P.append(chip(44,276,280,86,"fleetd  =  orbit + osquery + Desktop",["osquery runs read-only SQL","over the OS (no changes)"],TEAL))
P.append(chip(44,452,280,196,"Windows OS surfaces",[
    "Windows Update Agent API  (patches)","Chocolatey  (3rd-party apps)",
    "WMI · Registry · Services","BitLocker · Defender · Firewall",
    "osquery tables: bitlocker_info,","windows_security_center, registry,","programs, logical_drives, os_version"],GRAY))
# local interactions
P.append(arrow(150,194,150,452,GRAY,"apply",dash=False,w=1.5))
P.append(arrow(230,362,230,452,TEAL,"read",dash=True,w=1.5))

# ---------- INTERNET / DNS / TLS band ----------
P.append(zone(356,70,150,592,"INTERNET · DNS · TLS",AMBER))
P.append(chip(366,108,130,96,"DuckDNS",["nbcepm.duckdns.org","+ *.nbcepm (rmm/","api/mesh)","nbcfleet.duckdns.org"],AMBER,tsize=12))
P.append(chip(366,220,130,74,"Let's Encrypt",["TLS certs via","HTTP-01 (:80)"],AMBER,tsize=12))
P.append(txt(431,330,"Agents:",10.5,GRAY,"bold"))
P.append(txt(431,346,"outbound 443 only.",9.5,GRAY))
P.append(txt(431,360,"No inbound to the",9.5,GRAY))
P.append(txt(431,374,"endpoint (no VPN).",9.5,GRAY))

# ---------- AWS zone ----------
P.append(zone(518,70,938,592,"AWS · us-west-2 · default VPC / public subnet / Internet Gateway",NAVY))

# Fleet instance (top)
P.append(rect(538,104,900,176,WHITE,TEAL,rx=10,sw=2,op=1))
P.append(txt(552,124,"EC2 #2 · FleetDM   (Ubuntu 22.04 · t3.medium · Docker Compose · managed via SSM)",12.5,TEAL,"bold","start"))
P.append(chip(552,134,300,132,"Fleet Server (Go)",["serves UI + REST API +","osquery TLS endpoints","TLS :443 (own cert)","evaluates CP-01..08 policies"],TEAL,tsize=12))
P.append(chip(868,134,180,132,"MySQL 8",["hosts, policies,","query results","TCP :3306"],TEAL,tsize=12))
P.append(chip(1064,134,150,132,"Redis 7",["live-query results,","cache","TCP :6379"],TEAL,tsize=12))
P.append(chip(1230,134,194,132,"Host tooling",["certbot (TLS issue/renew)","fleetctl (setup, apply","policies, build MSI)","Docker engine"],GRAY,tsize=12))
# internal fleet links
P.append(arrow(852,200,868,200,GRAY,":3306",w=1.5,lsize=9))
P.append(arrow(1048,200,1064,200,GRAY,":6379",w=1.5,lsize=9))

# TRMM instance (bottom)
P.append(rect(538,300,900,350,WHITE,BLUE,rx=10,sw=2,op=1))
P.append(txt(552,320,"EC2 #1 · Tactical RMM   (Ubuntu 22.04 · t3.medium · systemd services · managed via SSM)",12.5,BLUE,"bold","start"))
P.append(chip(552,330,872,40,"nginx — TLS termination + reverse proxy   (:443 public, :80 ACME)",[],NAVY,tsize=12))
# service grid row1
P.append(chip(552,382,272,72,"Vue Frontend (SPA)",["the web UI assets"],BLUE,tsize=12))
P.append(chip(836,382,290,72,"Django REST API (uWSGI)",["core app: assets, patch,","scripts, scheduling"],BLUE,tsize=12))
P.append(chip(1138,382,286,72,"daphne (ASGI)",["WebSockets / Channels","for live UI updates"],BLUE,tsize=12))
# row2
P.append(chip(552,466,272,72,"Celery + Celery Beat",["task queue +","scheduled jobs"],PURPLE,tsize=12))
P.append(chip(836,466,290,72,"NATS + nats-api",["agent realtime bus","(commands/results)"],PURPLE,tsize=12))
P.append(chip(1138,466,286,72,"MeshCentral (Node.js)",["remote desktop/shell","relay (mesh.)"],PURPLE,tsize=12))
# stores row
P.append(chip(552,550,420,72,"PostgreSQL",["TRMM inventory, jobs, history","TCP :5432"],BLUE,tsize=12))
P.append(chip(1004,550,420,72,"Redis",["cache + Celery broker + NATS state","TCP :6379"],BLUE,tsize=12))
# internal trmm links
P.append(arrow(688,454,688,466,GRAY,"",w=1.3))
P.append(arrow(981,438,981,466,GRAY,"",w=1.3))
P.append(arrow(760,538,760,550,GRAY,":5432",w=1.3,lsize=9))
P.append(arrow(981,538,1100,550,GRAY,":6379",w=1.3,lsize=9))
P.append(arrow(700,370,700,382,GRAY,"",w=1.3))

# ---------- cross-zone data flows ----------
# fleetd -> Fleet
P.append(arrow(324,300,552,200,TEAL,"HTTPS 443 → nbcfleet  (enroll · live queries · results)",w=2.6,lsize=10,loff=22))
# TRMM agent -> nginx
P.append(arrow(324,150,552,350,BLUE,"HTTPS 443 → api/rmm  (REST + NATS realtime/WSS)",w=2.6,lsize=10,loff=-26))
# Mesh agent -> MeshCentral (via nginx reverse proxy on mesh.)
P.append(arrow(324,235,552,420,PURPLE,"WSS 443 → mesh.",w=2.2,lsize=10,loff=8))
# Let's Encrypt -> both :80
P.append(arrow(496,250,552,160,AMBER,"HTTP-01 :80",w=1.8,lsize=9,loff=-2))
P.append(arrow(496,275,552,345,AMBER,"",w=1.8))
# DuckDNS resolve (dashed) to endpoint
P.append(arrow(366,150,324,130,AMBER,"DNS",dash=True,w=1.4,lsize=9))

# ---------- ADMIN band ----------
P.append(zone(24,688,1432,116,"OPERATORS / ADMIN",GREEN))
P.append(chip(60,724,420,62,"Admin Browser",["TRMM UI (rmm.) + Fleet UI (nbcfleet) — HTTPS :443"],GREEN,tsize=12))
P.append(chip(510,724,520,62,"Admin Workstation (macOS)",["Terraform + AWS CLI · SSM Session / Run Command (over :443)"],GREEN,tsize=12))
P.append(chip(1060,724,360,62,"Why SSM, not SSH",["corp network blocks outbound :22 → manage boxes via SSM/443"],RED,tsize=12))
# admin -> UIs (443) and -> SSM
P.append(arrow(270,724,820,650,GREEN,"HTTPS :443 (UIs)",w=2,lsize=10,loff=20))
P.append(arrow(770,724,1100,650,GREEN,"SSM :443 (manage)",w=2,lsize=10,loff=30))

# ---------- legend ----------
ly=836
P.append(txt(24,ly,"Legend:",11,NAVY,"bold","start"))
items=[("Agents/Web",BLUE),("Compliance (Fleet)",TEAL),("Queue/Realtime/Remote",PURPLE),("DNS/TLS",AMBER),("Admin",GREEN),("OS / data",GRAY)]
lx=90
for name,c in items:
    P.append(rect(lx,ly-11,14,14,c,"none",rx=3,sw=0)); P.append(txt(lx+20,ly,name,10.5,GRAY,"normal","start"))
    lx+=len(name)*7+44
P.append(txt(24,ly+22,"Solid arrow = network flow (protocol/port labeled). Dashed = DNS resolution / local OS read. All endpoint↔cloud traffic is agent-initiated outbound 443.",10,GRAY,"normal","start"))

SVG=(f'<svg xmlns="http://www.w3.org/2000/svg" width="1480" height="980" '
     f'viewBox="0 0 1480 980">{DEFS}<g {F}>'+"".join(P)+'</g></svg>\n')
with open(os.path.join(HERE,"architecture-detailed.svg"),"w") as f: f.write(SVG)
print("wrote architecture-detailed.svg")
