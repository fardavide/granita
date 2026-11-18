# Recheck remembered routes for worktree list reads

On 18 November 2026, the iPhone verified its Mac on the home network at 14:17 UTC. After leaving
home, opening the Mac again between 15:08 and 15:12 UTC showed “Connected on this network” and
sent each worktree snapshot request to the previous LAN address. No new route selection appeared
in the phone logs. Back navigation cancelled pending reads, and the cached connection survived
because only a transport failure had been used to mark it unreachable.

A worktree list read reruns route selection. When the pairing has a saved Tailscale endpoint, its
pinned HTTPS check takes part in the existing race. The loading screen uses the route reported by
that attempt. If discovery fails, a previously verified LAN address can be used after a fresh
pinned health check. When the route and pairing match the existing connection, reuse the session.
File reads and live updates share the chosen connection.
