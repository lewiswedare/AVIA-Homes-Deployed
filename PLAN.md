# Add a Mac version of AVIA Homes via Mac Catalyst

## What you'll get

A native Mac app that mirrors the iOS app exactly — same screens, same data, same login. Staff and clients can open AVIA Homes on their Mac and use every feature available on iPhone and iPad.

## Features

- Full parity with the iOS app — CRM, leads, foundation calls, scheduling, display home visits, messaging, and admin tools all available on Mac
- Single sign-on across iPhone, iPad and Mac (same account, same data, synced live)
- Native Mac window with resizable layout that adapts to larger screens
- Mac menu bar with standard shortcuts (copy, paste, find, new, close window)
- Keyboard shortcuts for common actions (search leads, create new contact, jump between tabs)
- Click-to-call and click-to-email handled by macOS so calls and emails open in the right Mac apps
- Drag-and-drop file uploads (e.g. dropping a document onto a lead) where the iOS app uses pickers
- Trackpad-friendly scrolling, hover states on buttons and rows, and right-click context menus on lists

## Design

- Clean, Mac-native feel using the same AVIA branding, colours and typography as the iOS app
- Wider layouts on larger windows: lists on the left, details on the right, instead of stacking screens
- Sidebar navigation on Mac (replacing the bottom tab bar) with the same sections — Dashboard, Leads, Calendar, Display Homes, Messages, Settings
- Smooth window resizing with a sensible minimum size so layouts never feel cramped
- Same liquid-glass cards, gradients and accent colours as iOS for a consistent brand experience

## How it's delivered

- The Mac version runs from the same codebase as the iOS app, so any future change you ask for shows up on iPhone, iPad and Mac at once
- Built with Apple's Mac Catalyst, meaning it's a true Mac app (not a window mirror) — installable from the Mac App Store later if you choose
- Distributed alongside the iOS app under the same Apple developer account

## What I'll set up

- Turn on Mac support for the existing app
- Adjust a handful of screens that need a slightly different layout on Mac (sidebar instead of tabs, wider detail panes)
- Wire up Mac-specific niceties: window title, menu bar items, keyboard shortcuts, hover effects
- Confirm the camera/permissions/notifications behave correctly on Mac (and gracefully hide anything that doesn't apply, like in-app camera capture)
- Test the build to make sure everything compiles for Mac

## What you'll need to do later

- When you're ready to ship, sign in to App Store Connect and add Mac as a distribution platform — I'll prepare everything on the build side so it's ready when you are
