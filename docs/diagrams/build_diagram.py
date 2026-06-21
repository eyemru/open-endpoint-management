#!/usr/bin/env python3
"""
Generates the Stage-1 (assemble-first) architecture diagram in two forms:

  - architecture.drawio : editable draw.io / diagrams.net source (mxGraph XML)
  - architecture.svg     : rendered SVG for embedding in docs. The draw.io source
                           is embedded in the SVG's `content` attribute, so the SVG
                           re-opens (and round-trips) in draw.io for editing.

Run:  python3 docs/diagrams/build_diagram.py
"""
import html
import os

HERE = os.path.dirname(__file__)

# --- Editable draw.io source (mxGraph XML) ---------------------------------
DRAWIO = '''<mxfile host="app.diagrams.net" type="device">
  <diagram id="arch-stage1" name="Architecture (Stage 1)">
    <mxGraphModel dx="1000" dy="640" grid="1" gridSize="10" guides="1" tooltips="1"
        connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1000"
        pageHeight="600" math="0" shadow="0">
      <root>
        <mxCell id="0"/>
        <mxCell id="1" parent="0"/>

        <mxCell id="epg" value="Windows 10 / 11 endpoints  (~500 desktops + roaming laptops)"
            style="rounded=1;whiteSpace=wrap;html=1;fillColor=#F2F5F8;strokeColor=#1B6CA8;verticalAlign=top;fontStyle=1;fontColor=#0B2545;fontSize=13;arcSize=6;"
            vertex="1" parent="1"><mxGeometry x="40" y="70" width="300" height="400" as="geometry"/></mxCell>
        <mxCell id="fleetd" value="fleetd agent (osquery)&#10;Inventory + compliance telemetry"
            style="rounded=1;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#1B6CA8;fontColor=#0B2545;fontSize=12;"
            vertex="1" parent="1"><mxGeometry x="65" y="140" width="250" height="95" as="geometry"/></mxCell>
        <mxCell id="trmma" value="Tactical RMM agent (Go service)&#10;Patching · software · scripts&#10;MeshCentral (remote access)"
            style="rounded=1;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#13A89E;fontColor=#0B2545;fontSize=12;"
            vertex="1" parent="1"><mxGeometry x="65" y="265" width="250" height="130" as="geometry"/></mxCell>

        <mxCell id="dns" value="DuckDNS (dynamic DNS)  +  Let's Encrypt TLS"
            style="rounded=1;whiteSpace=wrap;html=1;fillColor=#0B2545;strokeColor=none;fontColor=#FFFFFF;fontSize=11;fontStyle=1;arcSize=40;"
            vertex="1" parent="1"><mxGeometry x="660" y="22" width="300" height="30" as="geometry"/></mxCell>
        <mxCell id="awsg" value="AWS control plane  (POC: 1–2 EC2 instances)"
            style="rounded=1;whiteSpace=wrap;html=1;fillColor=#F2F5F8;strokeColor=#0B2545;verticalAlign=top;fontStyle=1;fontColor=#0B2545;fontSize=13;arcSize=5;"
            vertex="1" parent="1"><mxGeometry x="660" y="60" width="300" height="410" as="geometry"/></mxCell>
        <mxCell id="fleetsrv" value="FleetDM server  →  MySQL + Redis&#10;Inventory · policies · dashboard"
            style="rounded=1;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#1B6CA8;fontColor=#0B2545;fontSize=12;"
            vertex="1" parent="1"><mxGeometry x="685" y="120" width="250" height="110" as="geometry"/></mxCell>
        <mxCell id="trmmsrv" value="Tactical RMM  →  Postgres + Redis + NATS&#10;Patching · scripts · alerts · MeshCentral"
            style="rounded=1;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#13A89E;fontColor=#0B2545;fontSize=12;"
            vertex="1" parent="1"><mxGeometry x="685" y="255" width="250" height="140" as="geometry"/></mxCell>

        <mxCell id="admin" value="IT Admin / IT team"
            style="rounded=1;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#0B2545;fontColor=#0B2545;fontSize=12;fontStyle=1;"
            vertex="1" parent="1"><mxGeometry x="730" y="505" width="180" height="55" as="geometry"/></mxCell>

        <mxCell id="e1" value="HTTPS 443 · telemetry / live queries"
            style="endArrow=block;startArrow=block;html=1;strokeColor=#5A6B7B;fontColor=#5A6B7B;fontSize=11;"
            edge="1" parent="1" source="fleetd" target="fleetsrv"><mxGeometry relative="1" as="geometry"/></mxCell>
        <mxCell id="e2" value="HTTPS 443 · report / pull jobs"
            style="endArrow=block;startArrow=block;html=1;strokeColor=#5A6B7B;fontColor=#5A6B7B;fontSize=11;"
            edge="1" parent="1" source="trmma" target="trmmsrv"><mxGeometry relative="1" as="geometry"/></mxCell>
        <mxCell id="e3" value="HTTPS · dashboards"
            style="endArrow=block;html=1;strokeColor=#5A6B7B;fontColor=#5A6B7B;fontSize=11;"
            edge="1" parent="1" source="admin" target="awsg"><mxGeometry relative="1" as="geometry"/></mxCell>

        <mxCell id="note" value="Outbound 443 only — reaches roaming laptops (no inbound / VPN)"
            style="text;html=1;align=center;fontColor=#0B2545;fontSize=11;fillColor=#EAF1F6;rounded=1;strokeColor=none;"
            vertex="1" parent="1"><mxGeometry x="355" y="436" width="290" height="34" as="geometry"/></mxCell>
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>'''


# --- Rendered SVG body (kept visually consistent with the .drawio) ----------
def t(x, y, s, size=12, color="#0B2545", weight="normal", anchor="middle"):
    return (f'<text x="{x}" y="{y}" font-size="{size}" fill="{color}" '
            f'font-weight="{weight}" text-anchor="{anchor}">{html.escape(s)}</text>')


def box(x, y, w, h, stroke, fill="#FFFFFF", rx=8, sw=2):
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" ry="{rx}" '
            f'fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')


FONT = 'font-family="Helvetica, Arial, sans-serif"'
INNER = f'''
<rect x="0" y="0" width="1000" height="600" rx="14" fill="#FFFFFF"/>
<g {FONT}>
  <!-- Endpoints group -->
  {box(40, 70, 300, 400, "#1B6CA8", "#F2F5F8", rx=12, sw=2)}
  {t(190, 100, "Windows 10 / 11 endpoints", 15, "#0B2545", "bold")}
  {t(190, 120, "~500 desktops + roaming laptops", 11, "#5A6B7B")}

  {box(65, 140, 250, 95, "#1B6CA8")}
  {t(190, 173, "fleetd agent (osquery)", 14, "#0B2545", "bold")}
  {t(190, 195, "Inventory + compliance", 11, "#5A6B7B")}
  {t(190, 211, "telemetry", 11, "#5A6B7B")}

  {box(65, 265, 250, 130, "#13A89E")}
  {t(190, 298, "Tactical RMM agent", 14, "#0B2545", "bold")}
  {t(190, 316, "(Go Windows service)", 11, "#5A6B7B")}
  {t(190, 340, "Patching · software · scripts", 11, "#5A6B7B")}
  {t(190, 358, "MeshCentral (remote access)", 11, "#5A6B7B")}

  <!-- DNS / TLS pill -->
  <rect x="660" y="22" width="300" height="30" rx="15" fill="#0B2545"/>
  {t(810, 42, "DuckDNS (dynamic DNS)  +  Let's Encrypt TLS", 11.5, "#FFFFFF", "bold")}

  <!-- AWS group -->
  {box(660, 60, 300, 410, "#0B2545", "#F2F5F8", rx=10, sw=2)}
  {t(810, 90, "AWS control plane", 15, "#0B2545", "bold")}
  {t(810, 110, "POC: 1–2 EC2 instances", 11, "#5A6B7B")}

  {box(685, 124, 250, 106, "#1B6CA8")}
  {t(810, 156, "FleetDM server  →  MySQL + Redis", 12.5, "#0B2545", "bold")}
  {t(810, 180, "Inventory · policies · dashboard", 11, "#5A6B7B")}

  {box(685, 258, 250, 137, "#13A89E")}
  {t(810, 290, "Tactical RMM server", 12.5, "#0B2545", "bold")}
  {t(810, 310, "→ Postgres + Redis + NATS", 11, "#5A6B7B")}
  {t(810, 334, "Patching · scripts · alerts", 11, "#5A6B7B")}
  {t(810, 352, "MeshCentral (remote)", 11, "#5A6B7B")}

  <!-- Edges -->
  <line x1="318" y1="186" x2="682" y2="176" stroke="#5A6B7B" stroke-width="2"
        marker-end="url(#arr)" marker-start="url(#arrs)"/>
  {t(500, 150, "HTTPS 443 · telemetry / live queries", 11, "#5A6B7B")}

  <line x1="318" y1="330" x2="682" y2="326" stroke="#5A6B7B" stroke-width="2"
        marker-end="url(#arr)" marker-start="url(#arrs)"/>
  {t(500, 312, "HTTPS 443 · report / pull jobs", 11, "#5A6B7B")}

  <!-- roaming note -->
  <rect x="355" y="436" width="290" height="34" rx="8" fill="#EAF1F6"/>
  {t(500, 457, "Outbound 443 only — reaches roaming laptops", 11, "#0B2545", "bold")}

  <!-- Admin -->
  {box(730, 505, 180, 55, "#0B2545")}
  {t(820, 530, "IT Admin / IT team", 12.5, "#0B2545", "bold")}
  {t(820, 547, "manages via browser", 10.5, "#5A6B7B")}
  <line x1="820" y1="505" x2="820" y2="472" stroke="#5A6B7B" stroke-width="2"
        marker-end="url(#arr)"/>
  {t(690, 492, "HTTPS · dashboards", 10.5, "#5A6B7B", "normal", "end")}
</g>
'''

DEFS = '''
  <defs>
    <marker id="arr" markerWidth="10" markerHeight="8" refX="8" refY="3"
            orient="auto" markerUnits="strokeWidth">
      <path d="M0,0 L8,3 L0,6 Z" fill="#5A6B7B"/>
    </marker>
    <marker id="arrs" markerWidth="10" markerHeight="8" refX="0" refY="3"
            orient="auto" markerUnits="strokeWidth">
      <path d="M8,0 L0,3 L8,6 Z" fill="#5A6B7B"/>
    </marker>
  </defs>'''

content_attr = html.escape(DRAWIO, quote=True)
SVG = (f'<svg xmlns="http://www.w3.org/2000/svg" '
       f'xmlns:xlink="http://www.w3.org/1999/xlink" '
       f'width="1000" height="600" viewBox="0 0 1000 600" '
       f'content="{content_attr}">'
       f'{DEFS}{INNER}</svg>\n')

with open(os.path.join(HERE, "architecture.drawio"), "w") as f:
    f.write(DRAWIO)
with open(os.path.join(HERE, "architecture.svg"), "w") as f:
    f.write(SVG)
print("Wrote architecture.drawio and architecture.svg")
