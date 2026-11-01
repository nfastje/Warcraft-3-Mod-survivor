# UI System Quick Reference

## Ownership

| Presentation | Author | Draw/input owner |
|---|---|---|
| Main menu, campaign selector, lobby | `games/warcraft-3/menu/` | Menu library, gated by `CL_MenuActive()` |
| Loading screen | Game | Generic client loading layout |
| HUD and command card | `games/warcraft-3/game/hud/` | Generic client `svc_layout` handlers |
| In-game dialogs | Game | Generic client `svc_window` manager |

## Selection Flow

Client input sends the selection/order command and updates its local selection hint. The game's authoritative
selection path validates the entity set and authors command, inventory, queue, and information frames from
`games/warcraft-3/game/hud/`. Those frames travel through `svc_layout` to the generic client renderer and input
handlers. No menu callback, separate HUD query, or menu-owned unit cache participates.

Recipient-specific skin keys are resolved in the game before registering concrete texture paths. HUD templates
and media identities are rebuilt across map/save-load transitions; see [HUD Media Lifetime](../hud-media.md).

## Lifecycle

`CL_Init` initializes the renderer and menu. Loading suspends menu resources through Shutdown. During loading
and gameplay the menu receives no draw/input/command callbacks. Return-to-menu initializes its resources again.
The library itself stays loaded so registered function pointers remain valid.

## Verification

Run `make test` and `python3 tools/menu_boundary_audit.py`. The suite covers selection state, packet alignment,
exclusive screen/input/command dispatch, menu suspension/reinitialization, and per-recipient HUD textures.

See [UI architecture](ui.md), [screen flow](ui-flow.md), and the
[engine UI boundary](../../../architecture/ui-system.md).
