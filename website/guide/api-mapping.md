# Platform API mapping

Every public Dart API of `advanced_webview` and the native Android and iOS API it uses.
Use it to find the underlying behaviour (and its platform quirks) in the official Android and
Apple documentation, or to see which platform a feature is available on.

| Status | Meaning |
| --- | --- |
| Supported | Works on this platform. |
| Partial | Works with a documented difference. |
| Creation only | Read when the native view is created; ignored by `updateSettings`. |
| Not supported | No effect on this platform. |

::: tip Single source of truth
This page is rendered from [`website/data/api-mapping.json`](https://github.com/imk1t/advanced_webview/blob/main/website/data/api-mapping.json).
CI fails when a public Dart API has no entry, an entry names a Dart API that no longer exists, or a
cited native API no longer appears in the Kotlin / Swift sources.
:::

## Lifecycle and widget

<ApiMapping group="lifecycle" />

## Loading and history

<ApiMapping group="loading" />

## JavaScript

<ApiMapping group="javascript" />

## Events and navigation

<ApiMapping group="events" />

## Settings

<ApiMapping group="settings" />

## Cookies

<ApiMapping group="cookies" />
