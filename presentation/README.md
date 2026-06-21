# Executive Briefing Deck

An executive pitch for adopting the open-source endpoint management solution, framed for an
executive (CIO/CFO/CEO) of the fictional **Northbridge Community Bank** — built around
**risk, cost, and audit exposure**, not technical detail.

## Files

- **`Northbridge_EndpointManagement_ExecBrief.pptx`** — the deck (14 slides, 16:9, with
  speaker notes on every slide).
- **`build_deck.py`** — generator script (python-pptx). The `.pptx` is reproducible from it.

## Regenerate

```bash
pip install python-pptx     # if needed
python3 presentation/build_deck.py
```

## Story arc

1. **Title** — Securing every endpoint without the enterprise price tag.
2. **The question** — "Is every laptop encrypted and patched?" (we can't answer today).
3. **Current state** — manual, inconsistent, no visibility.
4. **The stakes** — breach, ransomware, audit findings (bank framing).
5. **The opportunity** — Know · Prove · Fix, on open source we control.
6. **What it does** — the three pillars.
7. **How it works** — devices phone home securely; reaches roaming laptops.
8. **Foundation** — trusted OSS (FleetDM/osquery, Tactical RMM), no lock-in.
9. **Assurance** — compliance & security controls, audit-ready.
10. **Economics** — ~$1.2k/yr vs. $18–42k/yr commercial (illustrative).
11. **Phased plan** — POC → pilot → fleet, with go/no-go gates.
12. **Risks & mitigations** — honest view (incl. the "no vendor" objection).
13. **The ask** — approve a 4–6 week, near-zero-cost POC on 2 devices.
14. **Thank you / Q&A.**

> Speaker notes carry the talking points and the "why" behind each slide — open the deck in
> Presenter View. Cost figures are explicitly illustrative, not quotes.
