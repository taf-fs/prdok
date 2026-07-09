# Prdok

A native iOS app for workplace shift management, built entirely in Swift and SwiftUI.

## What It Does

prdok connects employees to a shift scheduling backend via QR code or link pairing, then surfaces their schedule in a clean, focused interface. The app shows a live countdown to the current or next shift, a full calendar view with shift indicators, the ability to offer or remove shift availability, break timer utilities, and quick access to relevant workplace links.

## Key Features

- **QR & Link Pairing** — first-time setup pairs the device to an employee account by scanning a QR code or pasting a link; credentials are validated and exchanged with the backend before being stored securely in UserDefaults
- **Today View** — live-updating countdown (refreshes every minute via `TimelineView`) to the ongoing or next planned shift; adapts its copy based on how far away the shift is
- **Calendar** — month view built on top of [HorizonCalendar](https://github.com/airbnb/HorizonCalendar) with custom shift indicators, day detail sheets, shift statistics, and iCal export
- **Shift Offering** — employees can submit or retract availability for open slots directly from the calendar
- **Theming** — light / dark / system color scheme toggle with a custom accent color palette applied app-wide
- **Localization** — English and Czech, driven by `Localizable.xcstrings`
- **Notifications** — local notifications via `NotificationManager`
- **Links tabs** — embedded WKWebView screens for internal tooling and quick-access workplace links

## Tech Stack

| Area | Choice |
|---|---|
| Language | Swift 5.9+ |
| UI | SwiftUI |
| Async | Swift Concurrency (`async`/`await`, `Task`, `MainActor`) |
| Networking | `URLSession` with form URL-encoded POST requests |
| Data layer | Repository + Service pattern with in-memory caching |
| Calendar | [HorizonCalendar](https://github.com/airbnb/HorizonCalendar) (Airbnb OSS) |
| QR Scanning | [CodeScanner](https://github.com/twostraws/CodeScanner) |
| Persistence | `UserDefaults`, `AppStorage` |

## Architecture

The app is built on MVVM. ViewModels drive async data fetching via Swift Concurrency and publish state to SwiftUI views, with a repository and service layer underneath handling caching and networking.

## Requirements

- iOS 17+
- Xcode 16+
- Access to the backend API (credentials configured via `Config.plist`)

---

# Prdok 🇨🇿

Nativní iOS aplikace pro správu pracovních směn, napsaná celá ve Swift a SwiftUI.

## Co dělá

prdok propojí zařízení se zaměstnaneckým účtem přes QR kód nebo odkaz a zobrazí rozvrh směn v přehledném rozhraní. Aplikace ukazuje živý odpočet do aktuální nebo nadcházející směny, úplný kalendářní pohled s indikátory směn, možnost nabídnout nebo odebrat dostupnost a rychlý přístup k pracovním odkazům.

## Hlavní funkce

- **Párování přes QR a odkaz** — první spuštění propojí zařízení se zaměstnaneckým účtem; přihlašovací údaje jsou ověřeny a bezpečně uloženy
- **Dnešní pohled** — odpočet aktualizovaný každou minutu (přes `TimelineView`) do probíhající nebo nadcházející směny; text se přizpůsobuje podle toho, jak daleko směna je
- **Kalendář** — měsíční pohled postavený na [HorizonCalendar](https://github.com/airbnb/HorizonCalendar) s vlastními indikátory směn, detailem dne, statistikami a exportem do iCal
- **Nabídka směn** — zaměstnanci mohou přímo z kalendáře přidat nebo odebrat svou dostupnost
- **Motivy** — přepínání světlého / tmavého / systémového motivu s vlastní barevnou paletou
- **Lokalizace** — čeština a angličtina pomocí `Localizable.xcstrings`
- **Notifikace** — lokální upozornění přes `NotificationManager`
- **Odkazy na web** — vložené WKWebView pro interní nástroje a pracovní odkazy

## Technologie

| Oblast | Volba |
|---|---|
| Jazyk | Swift 5.9+ |
| UI | SwiftUI |
| Asynchronicita | Swift Concurrency (`async`/`await`, `Task`, `MainActor`) |
| Síť | `URLSession` s form URL-encoded POST požadavky |
| Datová vrstva | vzor Repozitář se Službou s in-memory cache |
| Kalendář | [HorizonCalendar](https://github.com/airbnb/HorizonCalendar) (Airbnb OSS) |
| Skenování QR | [CodeScanner](https://github.com/twostraws/CodeScanner) |
| Persistence | `UserDefaults`, `AppStorage` |

## Architektura

Aplikace je postavena na MVVM. ViewModely řídí asynchronní načítání dat přes Swift Concurrency a publikují stav do SwiftUI views, přičemž pod nimi leží vrstva repository a service zajišťující cache a síťovou komunikaci.

## Požadavky

- iOS 17+
- Xcode 16+
- Přístup k backendovému API (přihlašovací údaje nakonfigurovány v `Config.plist`)
