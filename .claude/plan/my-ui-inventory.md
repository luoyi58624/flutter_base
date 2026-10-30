# my-ui 当前源库清单

核对日期：2026-10-30。真源：D:/project/html/my-ui。当前 Vue 导出 **54** 个组件（packages/vue/index.ts:6-67），另有 popup API、公共类型、共享状态等非视觉模块。
基准优先级：packages/core/my-ui.css 和 my-ui.js > Vue 绑定 > example；reference 是历史设计，不覆盖当前实现。README.md:3 明确示例主题独立于组件默认主题。此清单记录源码规格，不代表 Flutter 已通过像素验收。

## 内核与公共约定

- CSS 全局明暗 token：packages/core/my-ui.css:10-68；背景、卡片、填充、边框、正文/次文、gray、hover、press、selected-background，五组阴影，overlay 背景/4px blur，success/warning/danger/primary/primary-text。
- 字重 400/500/600/700、正文 15、focus-visible 2px 主色 + 3px offset、reduced-motion：packages/core/my-ui.css:82-149。
- 原生 value/onChange 与 Vue modelValue/update:modelValue；adapter.ts:51-66；实例 update/destroy 保留节点并释放生命周期：README.md:65-71、packages/vue/adapter.ts:89-106。
- Button/Card/ListRow 的 touch down 默认 0ms，up 从按下起保留至少 100ms；移动超 10px/滚动/取消清理；packages/core/my-ui.js:1118-1220；README.md:139-157。
- CSS 的 px 视为 Flutter 逻辑像素。本轮不测量 Windows 截图，不应用 1.75 的截图反算。

## 组件逐项清单

### AppBar

- 契约证据：packages/vue/components/AppBar.vue:1-28；核心：packages/core/my-ui.js:1705。
- Props / 变体：`{ title?: string subtitle?: string back?: boolean backLabel?: string center?: boolean sticky?: boolean }`。
- Events：`{ back: [event: MouseEvent] }`。
- 默认值：`{ title: '', subtitle: '', back: false, backLabel: '返回', center: true, sticky: false }`。
- 核心静态插槽：leading、default、actions；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--app-bar-height`、`--border`、`--card-background`、`--text`、`--app-bar-side`、`--app-bar-top`、`--font-weight-subtitle`、`--text-secondary`、`--press`。
- 视觉证据：packages/core/my-ui.css:3908-3929（AppBar）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── AppBar ────────────────────────────────────────────── */ .my-app-bar[data-my-app-bar]` → `display: flex; flex: 0 0 auto; align-items: center; gap: 12px; min-height: var(--app-bar-height, 60px); padding: 8px 12px; margin: 0; border-bottom: 1px solid var(--border); background: var(--card-background); color: var(--text);`
- `.my-app-bar-leading[data-my-app-bar], .my-app-bar-leading-slot[data-my-app-bar], .my-app-bar-actions[data-my-app-bar]` → `display: flex; align-items: center; flex: 0 0 auto; width: max-content; gap: 4px;`
- `.my-app-bar-body[data-my-app-bar]` → `flex: 1; min-width: 0;`
- `.my-app-bar-title[data-my-app-bar]` → `font-size: 17px; font-weight: var(--font-weight-subtitle, 600); line-height: 1.5; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;`
- `.my-app-bar-subtitle[data-my-app-bar]` → `margin-top: 1px; color: var(--text-secondary); font-size: 11px; line-height: 1.5; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;`
- `.my-app-bar-back[data-my-app-bar], .my-notice-close[data-my-notice], .my-upload-action[data-my-upload]` → `display: inline-flex; align-items: center; justify-content: center; flex: 0 0 auto; padding: 0; border: 0; background: transparent; color: inherit;`
- `.my-app-bar-back[data-my-app-bar]` → `width: 40px; height: 40px; border-radius: 50%;`
- `.my-app-bar-back svg[data-my-app-bar]` → `width: 22px; height: 22px; rotate: 180deg;`

</details>

### Avatar

- 契约证据：packages/vue/components/Avatar.vue:1-28；核心：packages/core/my-ui.js:1396。
- Props / 变体：`{ src?: string alt?: string text?: string size?: number ∣ string shape?: 'circle' ∣ 'square' }`。
- Events：`{ load: [event: Event] error: [event: Event] }`。
- 默认值：`{ alt: '', size: 40, shape: 'circle' }`。
- 核心静态插槽：default；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--avatar-size`、`--avatar-background`、`--fill`、`--avatar-color`、`--text-secondary`、`--font-weight-action`。
- 视觉证据：packages/core/my-ui.css:3330-3380（Avatar）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Avatar ───────────────────────────────────────────── */ .my-avatar[data-my-avatar]` → `position: relative; display: inline-flex; align-items: center; justify-content: center; flex: 0 0 auto; width: var(--avatar-size, 40px); height: var(--avatar-size, 40px); overflow: hidden; vertical-align: middle; border-radius: 50%; background: var(--avatar-background, var(--fill)); color: var(--avatar-color, var(--text-secondary)); font-size: calc(var(--avatar-size, 40px) * 0.36); font-weight: var(--font-weight-action, 500); line-height: 1; user-select: none;`
- `.my-avatar.my-square[data-my-avatar]` → `border-radius: 25%;`
- `.my-avatar-fallback[data-my-avatar]` → `display: flex; align-items: center; justify-content: center; width: 100%; height: 100%;`
- `.my-avatar-fallback > span[data-my-avatar]` → `max-width: 100%; padding-inline: 2px; overflow: hidden; white-space: nowrap; text-overflow: ellipsis;`
- `.my-avatar-fallback[data-my-avatar] svg` → `width: 50%; height: 50%;`
- `img[data-my-avatar]` → `position: absolute; inset: 0; display: block; width: 100%; height: 100%; object-fit: cover; border-radius: inherit;`

</details>

### Badge

- 契约证据：packages/vue/components/Badge.vue:1-25；核心：packages/core/my-ui.js:1565。
- Props / 变体：`{ value?: number ∣ string max?: number dot?: boolean showZero?: boolean hidden?: boolean label?: string }`。
- Events：`{}`。
- 默认值：`{ max: 99, dot: false, showZero: false, hidden: false }`。
- 核心静态插槽：default；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--badge-ring`、`--card-background`、`--badge-background`、`--danger`、`--badge-color`、`--font-weight-action`。
- 视觉证据：packages/core/my-ui.css:3599-3656（Badge）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Badge ───────────────────────────────────────────── */ .my-badge[data-my-badge]` → `position: relative; display: inline-flex; align-items: center; justify-content: center; vertical-align: middle; flex: 0 0 auto; line-height: 1;`
- `.my-badge-indicator[data-my-badge]` → `position: absolute; z-index: 1; top: 0; right: 0; display: inline-flex; align-items: center; justify-content: center; min-width: 20px; height: 20px; padding-inline: 4px; border: 2px solid var(--badge-ring, var(--card-background)); border-radius: 999px; background: var(--badge-background, var(--danger)); color: var(--badge-color, light-dark(#fff, #211013)); font-size: 11px; font-weight: var(--font-weight-action, 500); line-height: 16px; white-space: nowrap; translate: 50% -50%; pointer-events: none;`
- `.my-badge-indicator.my-dot[data-my-badge]` → `min-width: 10px; width: 10px; height: 10px; padding: 0;`
- `.my-standalone .my-badge-indicator[data-my-badge]` → `position: static; border: 0; font-size: 12px; padding-inline: 6px; translate: none;`
- `.my-standalone .my-badge-indicator.my-dot[data-my-badge]` → `padding: 0; width: 8px; min-width: 8px; height: 8px;`

</details>

### Button

- 契约证据：packages/vue/components/Button.vue:1-33；核心：packages/core/my-ui.js:1243。
- Props / 变体：`{ variant?: 'primary' ∣ 'outline' ∣ 'text' ∣ 'icon' ∣ 'bare' ∣ 'link' ∣ 'round' icon?: IconName disabled?: boolean loading?: boolean selected?: boolean delayTouchDown?: number delayTouchUp?: number type?: 'button' ∣ 'submit' ∣ 'reset' }`。
- Events：`{ click: [event: MouseEvent] }`。
- 默认值：`{ variant: 'primary', type: 'button', selected: undefined, delayTouchDown: 0, delayTouchUp: 100 }`。
- 核心静态插槽：default；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--font-weight-action`、`--primary`、`--primary-text`、`--border`、`--card-background`、`--fill`、`--text-secondary`、`--press`、`--hover`。
- 视觉证据：packages/core/my-ui.css:165-442（Button）。
<details><summary>尺寸、排版、动效规格</summary>

- `.my-button-content[data-my-button], .my-button-label[data-my-button]` → `display: inline-flex; align-items: center; justify-content: center; gap: inherit;`
- `.my-button[data-my-button]` → `border: 1px solid transparent; display: inline-flex; align-items: center; justify-content: center; font-weight: var(--font-weight-action, 500); transition: transform 0.16s ease, background-color 0.16s ease, border-color 0.16s ease, opacity 0.2s ease; white-space: nowrap; min-height: 44px; padding: 0 17px; font-size: 15px; border-radius: 13px; gap: 7px;`
- `.my-button[data-my-button] svg` → `width: 16px; height: 16px;`
- `.my-button.my-text-only[data-my-button]` → `color: var(--primary); background: transparent; padding-inline: 8px; opacity: 1; transform: none; touch-action: manipulation; transition: opacity 0.2s ease, color 0.15s ease;`
- `.my-icon-button[data-my-button]` → `display: inline-grid; place-items: center; color: var(--text-secondary); background: var(--fill); border: 1px solid var(--border); transition: transform 0.16s ease, background-color 0.16s ease, opacity 0.2s ease; width: 44px; height: 44px; border-radius: 12px;`
- `.my-icon-button[data-my-button] svg` → `width: 19px; height: 19px;`
- `.my-icon-button.my-bare-icon[data-my-button]` → `background: transparent; border-color: transparent; color: var(--text-secondary); opacity: 1; transform: none; touch-action: manipulation; transition: opacity 0.2s ease, color 0.15s ease;`
- `.my-round-arrow[data-my-button]` → `width: 46px; height: 46px; border: 1px solid var(--border); display: grid; place-items: center; border-radius: 14px; background: var(--fill); color: var(--primary); transform: scale(1); transform-origin: center; touch-action: manipulation; transition: transform 0.16s cubic-bezier(0.2, 0.7, 0.2, 1), background-color 0.15s ease, border-color 0.15s ease, color 0.15s ease;`
- `.my-round-arrow[data-my-button] svg` → `width: 17px; height: 17px;`
- `.my-underlink[data-my-button]` → `display: inline-flex; min-height: 44px; align-items: center; gap: 6px; align-self: flex-start; color: var(--primary); padding: 0; border: 0; background: none; font-size: 14px; font-weight: var(--font-weight-action, 500); margin-top: 24px; opacity: 1; transform: none; touch-action: manipulation; transition: opacity 0.2s ease, color 0.15s ease;`
- `.my-underlink[data-my-button] svg` → `width: 14px; height: 14px;`
- `.my-button[data-my-button]:not(.my-text-only):not(:disabled)` → `transform: scale(1); transform-origin: center; touch-action: manipulation; transition: transform 0.16s cubic-bezier(0.2, 0.7, 0.2, 1), background-color 0.15s ease, border-color 0.15s ease, color 0.15s ease;`
- `.my-icon-button[data-my-button]:not(.my-bare-icon)` → `transform: scale(1); transform-origin: center; touch-action: manipulation; transition: transform 0.16s cubic-bezier(0.2, 0.7, 0.2, 1), background-color 0.15s ease, border-color 0.15s ease, color 0.15s ease;`
- `.my-button[data-my-button]` → `padding: 0 17px;`
- `.my-button[data-my-button]` → `padding: 0 13px; font-size: 15px; min-height: 44px;`

</details>

### Calendar

- 契约证据：packages/vue/components/Calendar.vue:1-38；核心：packages/core/my-ui.js:6590。
- Props / 变体：`{ modelValue?: T range?: boolean month?: string min?: string max?: string disabledDate?: (date: string) => boolean firstDayOfWeek?: number label?: string disabled?: boolean }`。
- Events：`{ 'update:modelValue': [value: T] select: [value: T] 'month-change': [value: string] }`。
- 默认值：`{ range: false, firstDayOfWeek: 1, label: '日历', disabled: false }`。
- 核心静态插槽：无静态 c.slot 调用；动态出口见核心实现；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--calendar-width`、`--text`、`--font-weight-subtitle`、`--text-secondary`、`--primary`、`--calendar-day-size`、`--primary-text`、`--hover`、`--press`。
- 视觉证据：packages/core/my-ui.css:1510-1595（DatePicker / TimePicker / Calendar）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── DatePicker / TimePicker / Calendar ───────────────────────── */ /* 日期和时间滚轮沿用 Picker 变量，独立日历用紧凑的七列网格。 */ .my-date-picker[data-my-date-picker], .my-time-picker[data-my-time-picker]` → `min-width: 0;`
- `.my-calendar[data-my-calendar]` → `width: 100%; max-width: var(--calendar-width, 360px); min-width: 0; color: var(--text); font-size: 14px; font-variant-numeric: tabular-nums;`
- `.my-calendar-header[data-my-calendar]` → `display: flex; align-items: center; justify-content: space-between; gap: 8px; margin-bottom: 18px;`
- `.my-calendar-heading[data-my-calendar]` → `font-size: 17px; font-weight: var(--font-weight-subtitle, 600); white-space: nowrap;`
- `.my-calendar-nav[data-my-calendar]` → `display: flex; align-items: center; gap: 4px;`
- `.my-calendar-nav-button[data-my-calendar], .my-calendar-today[data-my-calendar]` → `display: inline-flex; align-items: center; justify-content: center; flex: 0 0 auto; height: 32px; padding: 0; border: 0; border-radius: 8px; background: transparent; color: var(--text-secondary); transition: background 120ms, color 120ms;`
- `.my-calendar-nav-button[data-my-calendar]` → `width: 32px;`
- `.my-calendar-nav-button svg[data-my-calendar]` → `width: 18px; height: 18px;`
- `.my-calendar-today[data-my-calendar]` → `padding: 0 8px; font-size: 12px;`
- `.my-calendar-weekdays[data-my-calendar]` → `margin-bottom: 6px; color: var(--text-secondary); font-size: 12px; text-align: center; line-height: 28px;`
- `.my-calendar-week[data-my-calendar]` → `padding: 3px 0;`
- `.my-calendar-cell[data-my-calendar]` → `position: relative; display: flex; justify-content: center; align-items: center; min-width: 0;`
- `.my-calendar-day[data-my-calendar]` → `position: relative; display: flex; align-items: center; justify-content: center; width: min(var(--calendar-day-size, 36px), 100%); height: var(--calendar-day-size, 36px); padding: 0; border: 0; border-radius: 50%; background: transparent; color: var(--text); font-size: 14px; line-height: 1; transition: background 120ms, color 120ms;`
- `.my-calendar-day[aria-current="date"][data-my-calendar]::after` → `content: ""; position: absolute; bottom: 3px; width: 3px; height: 3px; border-radius: 50%; background: currentColor;`
- `.my-calendar-status[data-my-calendar]` → `margin-top: 12px; min-height: 20px; color: var(--text-secondary); font-size: 12px; line-height: 1.65; overflow-wrap: anywhere;`
- `.my-calendar button[data-my-calendar]` → `transition: none;`

</details>

### Card

- 契约证据：packages/vue/components/Card.vue:1-29；核心：packages/core/my-ui.js:1607。
- Props / 变体：`{ title?: string description?: string sample?: string interactive?: boolean delayTouchDown?: number delayTouchUp?: number }`。
- Events：`{ activate: [event: MouseEvent ∣ KeyboardEvent] }`。
- 默认值：`{ delayTouchDown: 0, delayTouchUp: 100 }`。
- 核心静态插槽：default；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--card-background`、`--border`、`--card-radius`、`--shadow`、`--card-padding`、`--card-header-gap`、`--font-weight-subtitle`、`--text-secondary`、`--font-weight`、`--card-press-scale`、`--card-press-background`、`--text`、`--card-hover-background`。
- 视觉证据：packages/core/my-ui.css:3657-3754（Card）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Card ───────────────────────────────────────────── */ /* 展示页通过变量定制卡片，避免越过作用域修改卡片内部标题。 */ .my-card[data-my-card]` → `min-width: 0; position: relative; background: var(--card-background, #fff); border: 1px solid color-mix(in srgb, var(--border) 65%, transparent); border-radius: var(--card-radius, 30px); box-shadow: var(--shadow); padding: var(--card-padding, 28px 29px 29px);`
- `.my-surface-head[data-my-card]` → `display: flex; align-items: flex-start; justify-content: space-between; gap: 18px; margin-bottom: var(--card-header-gap, 22px);`
- `.my-surface-head h3[data-my-card]` → `letter-spacing: -0.55px; margin: 0 0 7px; font-size: 20px; font-weight: var(--font-weight-subtitle, 600); line-height: 1.35;`
- `.my-surface-head p[data-my-card]` → `margin: 0; color: var(--text-secondary); font-size: 13px; line-height: 1.55;`
- `.my-sample-id[data-my-card]` → `font-size: 10px; color: var(--text-secondary); font-weight: var(--font-weight, 400); white-space: nowrap; padding-top: 6px; letter-spacing: 0.5px;`
- `.my-tappable-card[data-my-card]` → `cursor: pointer; touch-action: manipulation; -webkit-tap-highlight-color: transparent; -webkit-user-select: none; user-select: none; transform: scale(1); transform-origin: center; transition: transform 150ms ease-out, background-color 150ms ease-out;`
- `.my-card[data-my-card]` → `padding: var(--card-padding, 29px 28px 30px);`
- `.my-card[data-my-card]` → `border-radius: var(--card-radius, 26px); padding: var(--card-padding, 24px 22px 25px);`
- `.my-surface-head h3[data-my-card]` → `font-size: 20px;`
- `.my-surface-head p[data-my-card]` → `font-size: 13px;`
- `.my-sample-id[data-my-card]` → `font-size: 10px; padding-top: 7px;`
- `.my-surface-head[data-my-card]` → `gap: 10px;`
- `.my-surface-head h3[data-my-card]` → `font-size: 19px;`
- `.my-sample-id[data-my-card]` → `font-size: 9px; letter-spacing: 0;`

</details>

### CellGroup

- 契约证据：packages/vue/components/CellGroup.vue:1-34；核心：packages/core/my-ui.js:2729。
- Props / 变体：`{ title?: string description?: string mode?: ListMode modelValue?: string ∣ string[] options?: Option[] label?: string disabled?: boolean }`。
- Events：`{ 'update:modelValue': [value: string ∣ string[]] select: [item: Option] }`。
- 默认值：`{ mode: 'normal' }`。
- 核心静态插槽：default、item；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--text-secondary`、`--font-weight-subtitle`、`--list-border`、`--border`、`--list-radius`、`--card-background`、`--list-padding-block`、`--list-padding-inline`、`--list-divider-color`。
- 视觉证据：packages/core/my-ui.css:1762-1808（CellGroup）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── CellGroup ───────────────────────────────────────────── */ .my-cell-group[data-my-cell-group]` → `min-width: 0;`
- `.my-group-heading[data-my-cell-group]` → `padding: 0 2px; margin-bottom: 11px; color: var(--text-secondary); font-size: 13px; line-height: 1.6;`
- `.my-group-heading strong[data-my-cell-group]` → `font-size: 13px; font-weight: var(--font-weight-subtitle, 600);`
- `.my-group-heading p[data-my-cell-group]` → `margin: 3px 0 0;`
- `.my-group-body[data-my-cell-group]` → `border: var(--list-border, 1px solid var(--border)); border-radius: var(--list-radius, 18px); background: var(--card-background); overflow: hidden;`
- `/* 插槽占位使用 display: contents，分割线由内部 ListRow 绘制，不能重复挂到占位上。 */ .my-group-body[data-my-cell-group] > :not(:first-child, .my-row-slot)::before` → `content: ""; position: absolute; top: 0; left: var(--list-padding-inline, 16px); right: var(--list-padding-inline, 16px); height: 0; border-top: 1px solid var(--list-divider-color, var(--border)); pointer-events: none;`

</details>

### Checkbox

- 契约证据：packages/vue/components/Checkbox.vue:1-32；核心：共享注册/帮助函数，见对应 Vue useNative 调用。
- Props / 变体：`{ modelValue?: boolean value?: string label?: string description?: string indeterminate?: boolean disabled?: boolean name?: string }`。
- Events：`{ 'update:modelValue': [value: boolean] 'update:indeterminate': [value: boolean] }`。
- 默认值：`无显式 withDefaults，见原文件`。
- 核心静态插槽：无静态 c.slot 调用；动态出口见核心实现；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--choice-size`、`--gray`、`--card-background`、`--primary`、`--primary-text`、`--text`、`--font-weight-action`、`--text-secondary`、`--font-weight`、`--list-padding-block`、`--list-padding-inline`、`--hover`、`--press`。
- 视觉证据：packages/core/my-ui.css:582-711（ChoiceControl）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── ChoiceControl ───────────────────────────────────────────── */ .my-choice-control[data-my-choice-control]` → `display: inline-flex; align-items: center; gap: 11px; min-width: 0; min-height: 42px; padding: 7px 8px; border-radius: 10px; cursor: pointer; user-select: none; -webkit-user-select: none; -webkit-tap-highlight-color: transparent; touch-action: manipulation; transition: background-color 0.14s ease;`
- `input[data-my-choice-control]` → `appearance: none; -webkit-appearance: none; display: grid; place-items: center; flex: 0 0 var(--choice-size, 20px); width: var(--choice-size, 20px); height: var(--choice-size, 20px); margin: 0; border: 1.5px solid var(--gray); border-radius: 6px; background: var(--card-background); cursor: inherit; transition: background-color 0.15s ease, border-color 0.15s ease;`
- `input[type="radio"][data-my-choice-control]` → `border-radius: 50%;`
- `input[type="radio"][data-my-choice-control]:checked::after` → `content: ""; width: 7px; height: 7px; border-radius: 50%; background: var(--primary-text);`
- `input[type="checkbox"][data-my-choice-control]:checked::after` → `content: ""; width: 9px; height: 5px; border-left: 2px solid var(--primary-text); border-bottom: 2px solid var(--primary-text); transform: translateY(-1px) rotate(-45deg);`
- `input[type="checkbox"][data-my-choice-control]:indeterminate::after` → `content: ""; width: 9px; height: 2px; border: 0; border-radius: 1px; background: var(--primary-text); transform: none;`
- `.my-choice-copy[data-my-choice-control]` → `flex: 1; min-width: 0; overflow-wrap: anywhere;`
- `.my-choice-label[data-my-choice-control]` → `display: block; color: var(--text); font-size: 14px; font-weight: var(--font-weight-action, 500); line-height: 22px;`
- `.my-choice-description[data-my-choice-control]` → `display: block; margin-top: 3px; color: var(--text-secondary); font-size: 14px; font-weight: var(--font-weight, 400); line-height: 20px;`
- `.my-is-list[data-my-choice-control]` → `display: flex; position: relative; gap: 12px; padding: var(--list-padding-block, 14px) var(--list-padding-inline, 16px); border-radius: 0; --choice-size: 21px;`
- `.my-is-list .my-choice-label[data-my-choice-control]` → `font-size: 15px;`
- `.my-is-list input[type="radio"][data-my-choice-control]:checked::after` → `width: 8px; height: 8px;`
- `.my-is-list input[type="checkbox"][data-my-choice-control]:checked:not( :indeterminate )::after` → `width: 10px; height: 6px;`

</details>
- 视觉证据：packages/core/my-ui.css:712-745（ChoiceGroup）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── ChoiceGroup ───────────────────────────────────────────── */ .my-choice-group[data-my-choice-group]` → `min-width: 0; margin: 0; padding: 0; border: 0;`
- `legend[data-my-choice-group]` → `padding: 0; margin-bottom: 10px; color: var(--text-secondary); font-size: 13px; font-weight: var(--font-weight-action, 500); line-height: 20px;`
- `.my-choice-items[data-my-choice-group]` → `display: flex; flex-direction: column; align-items: stretch; gap: 4px; min-width: 0;`
- `.my-choice-items.my-inline[data-my-choice-group]` → `flex-direction: row; flex-wrap: wrap; align-items: center; gap: 4px 12px;`

</details>

### CheckboxGroup

- 契约证据：packages/vue/components/CheckboxGroup.vue:1-26；核心：共享注册/帮助函数，见对应 Vue useNative 调用。
- Props / 变体：`{ modelValue: string[] label: string options?: Option[] disabled?: boolean inline?: boolean name?: string }`。
- Events：`{ 'update:modelValue': [value: string[]] }`。
- 默认值：`无显式 withDefaults，见原文件`。
- 核心静态插槽：无静态 c.slot 调用；动态出口见核心实现；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--choice-size`、`--gray`、`--card-background`、`--primary`、`--primary-text`、`--text`、`--font-weight-action`、`--text-secondary`、`--font-weight`、`--list-padding-block`、`--list-padding-inline`、`--hover`、`--press`。
- 视觉证据：packages/core/my-ui.css:582-711（ChoiceControl）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── ChoiceControl ───────────────────────────────────────────── */ .my-choice-control[data-my-choice-control]` → `display: inline-flex; align-items: center; gap: 11px; min-width: 0; min-height: 42px; padding: 7px 8px; border-radius: 10px; cursor: pointer; user-select: none; -webkit-user-select: none; -webkit-tap-highlight-color: transparent; touch-action: manipulation; transition: background-color 0.14s ease;`
- `input[data-my-choice-control]` → `appearance: none; -webkit-appearance: none; display: grid; place-items: center; flex: 0 0 var(--choice-size, 20px); width: var(--choice-size, 20px); height: var(--choice-size, 20px); margin: 0; border: 1.5px solid var(--gray); border-radius: 6px; background: var(--card-background); cursor: inherit; transition: background-color 0.15s ease, border-color 0.15s ease;`
- `input[type="radio"][data-my-choice-control]` → `border-radius: 50%;`
- `input[type="radio"][data-my-choice-control]:checked::after` → `content: ""; width: 7px; height: 7px; border-radius: 50%; background: var(--primary-text);`
- `input[type="checkbox"][data-my-choice-control]:checked::after` → `content: ""; width: 9px; height: 5px; border-left: 2px solid var(--primary-text); border-bottom: 2px solid var(--primary-text); transform: translateY(-1px) rotate(-45deg);`
- `input[type="checkbox"][data-my-choice-control]:indeterminate::after` → `content: ""; width: 9px; height: 2px; border: 0; border-radius: 1px; background: var(--primary-text); transform: none;`
- `.my-choice-copy[data-my-choice-control]` → `flex: 1; min-width: 0; overflow-wrap: anywhere;`
- `.my-choice-label[data-my-choice-control]` → `display: block; color: var(--text); font-size: 14px; font-weight: var(--font-weight-action, 500); line-height: 22px;`
- `.my-choice-description[data-my-choice-control]` → `display: block; margin-top: 3px; color: var(--text-secondary); font-size: 14px; font-weight: var(--font-weight, 400); line-height: 20px;`
- `.my-is-list[data-my-choice-control]` → `display: flex; position: relative; gap: 12px; padding: var(--list-padding-block, 14px) var(--list-padding-inline, 16px); border-radius: 0; --choice-size: 21px;`
- `.my-is-list .my-choice-label[data-my-choice-control]` → `font-size: 15px;`
- `.my-is-list input[type="radio"][data-my-choice-control]:checked::after` → `width: 8px; height: 8px;`
- `.my-is-list input[type="checkbox"][data-my-choice-control]:checked:not( :indeterminate )::after` → `width: 10px; height: 6px;`

</details>
- 视觉证据：packages/core/my-ui.css:712-745（ChoiceGroup）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── ChoiceGroup ───────────────────────────────────────────── */ .my-choice-group[data-my-choice-group]` → `min-width: 0; margin: 0; padding: 0; border: 0;`
- `legend[data-my-choice-group]` → `padding: 0; margin-bottom: 10px; color: var(--text-secondary); font-size: 13px; font-weight: var(--font-weight-action, 500); line-height: 20px;`
- `.my-choice-items[data-my-choice-group]` → `display: flex; flex-direction: column; align-items: stretch; gap: 4px; min-width: 0;`
- `.my-choice-items.my-inline[data-my-choice-group]` → `flex-direction: row; flex-wrap: wrap; align-items: center; gap: 4px 12px;`

</details>

### Choices

- 契约证据：packages/vue/components/Choices.vue:1-29；核心：packages/core/my-ui.js:2562。
- Props / 变体：`{ modelValue: string ∣ string[] label: string options: Option[] type?: 'radio' ∣ 'checkbox' list?: boolean disabled?: boolean }`。
- Events：`{ 'update:modelValue': [value: string ∣ string[]] }`。
- 默认值：`{ type: 'radio' }`。
- 核心静态插槽：无静态 c.slot 调用；动态出口见核心实现；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--choice-size`、`--gray`、`--card-background`、`--primary`、`--primary-text`、`--text`、`--font-weight-action`、`--text-secondary`、`--font-weight`、`--list-padding-block`、`--list-padding-inline`、`--hover`、`--press`、`--list-border`、`--border`、`--list-radius`、`--list-divider-color`。
- 视觉证据：packages/core/my-ui.css:582-711（ChoiceControl）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── ChoiceControl ───────────────────────────────────────────── */ .my-choice-control[data-my-choice-control]` → `display: inline-flex; align-items: center; gap: 11px; min-width: 0; min-height: 42px; padding: 7px 8px; border-radius: 10px; cursor: pointer; user-select: none; -webkit-user-select: none; -webkit-tap-highlight-color: transparent; touch-action: manipulation; transition: background-color 0.14s ease;`
- `input[data-my-choice-control]` → `appearance: none; -webkit-appearance: none; display: grid; place-items: center; flex: 0 0 var(--choice-size, 20px); width: var(--choice-size, 20px); height: var(--choice-size, 20px); margin: 0; border: 1.5px solid var(--gray); border-radius: 6px; background: var(--card-background); cursor: inherit; transition: background-color 0.15s ease, border-color 0.15s ease;`
- `input[type="radio"][data-my-choice-control]` → `border-radius: 50%;`
- `input[type="radio"][data-my-choice-control]:checked::after` → `content: ""; width: 7px; height: 7px; border-radius: 50%; background: var(--primary-text);`
- `input[type="checkbox"][data-my-choice-control]:checked::after` → `content: ""; width: 9px; height: 5px; border-left: 2px solid var(--primary-text); border-bottom: 2px solid var(--primary-text); transform: translateY(-1px) rotate(-45deg);`
- `input[type="checkbox"][data-my-choice-control]:indeterminate::after` → `content: ""; width: 9px; height: 2px; border: 0; border-radius: 1px; background: var(--primary-text); transform: none;`
- `.my-choice-copy[data-my-choice-control]` → `flex: 1; min-width: 0; overflow-wrap: anywhere;`
- `.my-choice-label[data-my-choice-control]` → `display: block; color: var(--text); font-size: 14px; font-weight: var(--font-weight-action, 500); line-height: 22px;`
- `.my-choice-description[data-my-choice-control]` → `display: block; margin-top: 3px; color: var(--text-secondary); font-size: 14px; font-weight: var(--font-weight, 400); line-height: 20px;`
- `.my-is-list[data-my-choice-control]` → `display: flex; position: relative; gap: 12px; padding: var(--list-padding-block, 14px) var(--list-padding-inline, 16px); border-radius: 0; --choice-size: 21px;`
- `.my-is-list .my-choice-label[data-my-choice-control]` → `font-size: 15px;`
- `.my-is-list input[type="radio"][data-my-choice-control]:checked::after` → `width: 8px; height: 8px;`
- `.my-is-list input[type="checkbox"][data-my-choice-control]:checked:not( :indeterminate )::after` → `width: 10px; height: 6px;`

</details>
- 视觉证据：packages/core/my-ui.css:712-745（ChoiceGroup）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── ChoiceGroup ───────────────────────────────────────────── */ .my-choice-group[data-my-choice-group]` → `min-width: 0; margin: 0; padding: 0; border: 0;`
- `legend[data-my-choice-group]` → `padding: 0; margin-bottom: 10px; color: var(--text-secondary); font-size: 13px; font-weight: var(--font-weight-action, 500); line-height: 20px;`
- `.my-choice-items[data-my-choice-group]` → `display: flex; flex-direction: column; align-items: stretch; gap: 4px; min-width: 0;`
- `.my-choice-items.my-inline[data-my-choice-group]` → `flex-direction: row; flex-wrap: wrap; align-items: center; gap: 4px 12px;`

</details>
- 视觉证据：packages/core/my-ui.css:746-776（Choices）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Choices ───────────────────────────────────────────── */ .my-list-stack[data-my-choices]` → `min-width: 0; margin: 0; padding: 0; border: var(--list-border, 1px solid var(--border)); border-radius: var(--list-radius, 18px); background: var(--card-background); overflow: hidden;`
- `/* 首尾间距与分割线继续由列表容器负责，选择控件只复用绘制与命中。 */ .my-list-stack[data-my-choices] > .my-choice-control + .my-choice-control::before` → `content: ""; position: absolute; top: 0; left: var(--list-padding-inline, 16px); right: var(--list-padding-inline, 16px); height: 0; border-top: 1px solid var(--list-divider-color, var(--border)); pointer-events: none;`

</details>

### Collapse

- 契约证据：packages/vue/components/Collapse.vue:1-19；核心：packages/core/my-ui.js:6759。
- Props / 变体：`{ modelValue: T disabled?: boolean label?: string }`。
- Events：`{ 'update:modelValue': [value: T] }`。
- 默认值：`无显式 withDefaults，见原文件`。
- 核心静态插槽：default；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--border`、`--collapse-radius`、`--card-background`。
- 视觉证据：packages/core/my-ui.css:2285-2297（Collapse）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Collapse ───────────────────────────────────────────── */ .my-collapse[data-my-collapse]` → `min-width: 0; border: 1px solid var(--border); border-radius: var(--collapse-radius, 16px); background: var(--card-background); overflow: hidden;`

</details>

### CollapseItem

- 契约证据：packages/vue/components/CollapseItem.vue:1-19；核心：packages/core/my-ui.js:6775。
- Props / 变体：`{ value: string title?: string disabled?: boolean }`。
- Events：`{}`。
- 默认值：`无显式 withDefaults，见原文件`。
- 核心静态插槽：title、default；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--collapse-padding`、`--text`、`--font-weight-action`、`--text-secondary`、`--primary`、`--font-weight`、`--hover`、`--press`。
- 视觉证据：packages/core/my-ui.css:2298-2388（CollapseItem）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── CollapseItem ───────────────────────────────────────────── */ .my-collapse-trigger[data-my-collapse-item]` → `display: flex; align-items: center; justify-content: space-between; gap: 16px; width: 100%; min-height: 54px; padding: 16px var(--collapse-padding, 16px); border: 0; background: transparent; color: var(--text); text-align: left; cursor: pointer; -webkit-tap-highlight-color: transparent; transition: background-color 0.14s ease;`
- `.my-collapse-title[data-my-collapse-item]` → `flex: 1; min-width: 0; font-size: 15px; font-weight: var(--font-weight-action, 500); line-height: 22px; overflow-wrap: anywhere;`
- `.my-collapse-arrow[data-my-collapse-item]` → `flex: 0 0 18px; width: 18px; height: 18px; color: var(--text-secondary); transform: rotate(90deg); transition: transform 0.24s ease;`
- `.my-collapse-region[data-my-collapse-item]` → `display: grid; grid-template-rows: 0fr; visibility: hidden; transition: grid-template-rows 0.24s ease, visibility 0s 0.24s;`
- `.my-collapse-region.my-open[data-my-collapse-item]` → `grid-template-rows: 1fr; visibility: visible; transition: grid-template-rows 0.24s ease, visibility 0s;`
- `.my-collapse-clip[data-my-collapse-item]` → `min-height: 0; overflow: hidden;`
- `.my-collapse-content[data-my-collapse-item]` → `padding: 0 var(--collapse-padding, 16px) 16px; color: var(--text-secondary); font-size: 14px; font-weight: var(--font-weight, 400); line-height: 1.7; overflow-wrap: anywhere;`
- `.my-collapse-region[data-my-collapse-item], .my-collapse-region.my-open[data-my-collapse-item], .my-collapse-arrow[data-my-collapse-item]` → `transition: none;`

</details>

### Combobox

- 契约证据：packages/vue/components/Combobox.vue:1-49；核心：packages/core/my-ui.js:5051。
- Props / 变体：`{ modelValue: string options: Option[] label: string id?: string name?: string placeholder?: string clearable?: boolean disabled?: boolean loading?: boolean filter?: false ∣ ((query: string, option: Option) => boolean) emptyText?: string required?: boolean error?: string hint?: string }`。
- Events：`{ 'update:modelValue': [value: string] search: [query: string] select: [option: Option] }`。
- 默认值：`{ placeholder: '搜索或选择…', clearable: false, disabled: false, loading: false, filter: undefined, emptyText: '没有匹配的选项' }`。
- 核心静态插槽：option-leading、empty；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--list-padding-block`、`--text`、`--primary`、`--hover`、`--text-secondary`。
- 视觉证据：packages/core/my-ui.css:1149-1206（Combobox）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Combobox ───────────────────────────────────────────── */ .my-combobox[data-my-combobox]` → `min-width: 0;`
- `.my-combobox-content[data-my-combobox], .my-combobox-list[data-my-combobox]` → `margin: 0; padding: 0; outline: 0;`
- `.my-combobox-check[data-my-combobox]` → `width: 18px; height: 18px; color: var(--primary); visibility: hidden;`
- `.my-combobox-option[data-my-combobox] .my-leading-content` → `width: auto; height: auto; min-width: 20px; border-radius: 0; background: transparent; color: inherit;`
- `.my-combobox-status[data-my-combobox]` → `margin: 0; padding: 22px 16px; color: var(--text-secondary); text-align: center; font-size: 14px; line-height: 22px;`

</details>

### DatePicker

- 契约证据：packages/vue/components/DatePicker.vue:1-26；核心：共享注册/帮助函数，见对应 Vue useNative 调用。
- Props / 变体：`{ modelValue?: string ∣ null min?: string max?: string label?: string disabled?: boolean }`。
- Events：`{ 'update:modelValue': [value: string] }`。
- 默认值：`{ label: '选择日期', disabled: false }`。
- 核心静态插槽：无静态 c.slot 调用；动态出口见核心实现；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--calendar-width`、`--text`、`--font-weight-subtitle`、`--text-secondary`、`--primary`、`--calendar-day-size`、`--primary-text`、`--hover`、`--press`。
- 视觉证据：packages/core/my-ui.css:1510-1595（DatePicker / TimePicker / Calendar）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── DatePicker / TimePicker / Calendar ───────────────────────── */ /* 日期和时间滚轮沿用 Picker 变量，独立日历用紧凑的七列网格。 */ .my-date-picker[data-my-date-picker], .my-time-picker[data-my-time-picker]` → `min-width: 0;`
- `.my-calendar[data-my-calendar]` → `width: 100%; max-width: var(--calendar-width, 360px); min-width: 0; color: var(--text); font-size: 14px; font-variant-numeric: tabular-nums;`
- `.my-calendar-header[data-my-calendar]` → `display: flex; align-items: center; justify-content: space-between; gap: 8px; margin-bottom: 18px;`
- `.my-calendar-heading[data-my-calendar]` → `font-size: 17px; font-weight: var(--font-weight-subtitle, 600); white-space: nowrap;`
- `.my-calendar-nav[data-my-calendar]` → `display: flex; align-items: center; gap: 4px;`
- `.my-calendar-nav-button[data-my-calendar], .my-calendar-today[data-my-calendar]` → `display: inline-flex; align-items: center; justify-content: center; flex: 0 0 auto; height: 32px; padding: 0; border: 0; border-radius: 8px; background: transparent; color: var(--text-secondary); transition: background 120ms, color 120ms;`
- `.my-calendar-nav-button[data-my-calendar]` → `width: 32px;`
- `.my-calendar-nav-button svg[data-my-calendar]` → `width: 18px; height: 18px;`
- `.my-calendar-today[data-my-calendar]` → `padding: 0 8px; font-size: 12px;`
- `.my-calendar-weekdays[data-my-calendar]` → `margin-bottom: 6px; color: var(--text-secondary); font-size: 12px; text-align: center; line-height: 28px;`
- `.my-calendar-week[data-my-calendar]` → `padding: 3px 0;`
- `.my-calendar-cell[data-my-calendar]` → `position: relative; display: flex; justify-content: center; align-items: center; min-width: 0;`
- `.my-calendar-day[data-my-calendar]` → `position: relative; display: flex; align-items: center; justify-content: center; width: min(var(--calendar-day-size, 36px), 100%); height: var(--calendar-day-size, 36px); padding: 0; border: 0; border-radius: 50%; background: transparent; color: var(--text); font-size: 14px; line-height: 1; transition: background 120ms, color 120ms;`
- `.my-calendar-day[aria-current="date"][data-my-calendar]::after` → `content: ""; position: absolute; bottom: 3px; width: 3px; height: 3px; border-radius: 50%; background: currentColor;`
- `.my-calendar-status[data-my-calendar]` → `margin-top: 12px; min-height: 20px; color: var(--text-secondary); font-size: 12px; line-height: 1.65; overflow-wrap: anywhere;`
- `.my-calendar button[data-my-calendar]` → `transition: none;`

</details>

### Dialog

- 契约证据：packages/vue/components/Dialog.vue:1-43；核心：packages/core/my-ui.js:3772。
- Props / 变体：`{ modelValue: boolean title: string description?: string icon?: IconName ∣ false cancelText?: string ∣ false confirmText?: string center?: boolean danger?: boolean closeOnBackdrop?: boolean closeOnEscape?: boolean }`。
- Events：`{ 'update:modelValue': [value: boolean] confirm: [] cancel: [] 'after-leave': [] }`。
- 默认值：`{ icon: 'shield', cancelText: '取消', confirmText: '确认保存', center: true, closeOnBackdrop: true, closeOnEscape: true }`。
- 核心静态插槽：无静态 c.slot 调用；动态出口见核心实现；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--primary`、`--font-weight-action`、`--border`、`--danger`、`--press`、`--hover`、`--overlay-background`、`--overlay-backdrop-filter`、`--dialog-margin`、`--dialog-radius`、`--dialog-width`、`--dialog-padding`、`--card-background`、`--modal-shadow`、`--popup-shadow`、`--fill`、`--font-weight-subtitle`、`--gray`、`--text-secondary`。
- 视觉证据：packages/core/my-ui.css:2680-2741（PopupActions）。
<details><summary>尺寸、排版、动效规格</summary>

- `button[data-my-popup-actions]` → `position: relative; width: 100%; min-width: 0; border: 0; border-radius: 0; background: transparent; color: var(--primary); font: inherit; font-size: 16px; font-weight: var(--font-weight-action, 500); line-height: 24px; padding: 18px 16px calc(24px + env(safe-area-inset-bottom, 0px)); min-height: 66px; touch-action: manipulation; transition: background-color 0.14s;`
- `/* 短线由操作区居中定位，底部延伸留白仍属于按钮点击区。 */ .my-popup-actions.my-paired[data-my-popup-actions]::after` → `content: ""; position: absolute; inset-inline-start: 50%; top: 20px; height: 20px; width: 0; border-inline-start: 1px solid var(--border); pointer-events: none;`
- `button[data-my-popup-actions]:focus-visible::after` → `content: ""; position: absolute; inset: 6px; border: 2px solid var(--primary); border-radius: 12px; pointer-events: none;`

</details>
- 视觉证据：packages/core/my-ui.css:2742-2866（Dialog）。
<details><summary>尺寸、排版、动效规格</summary>

- `.my-overlay[data-my-dialog]` → `position: fixed; inset: 0; background: var(--overlay-background, rgb(0 0 0 / 0.34)); backdrop-filter: var(--overlay-backdrop-filter, blur(4px)); z-index: 100; display: grid; place-items: center; padding: var(--dialog-margin, 16px);`
- `.my-dialog-motion-enter-active[data-my-dialog], .my-dialog-motion-leave-active[data-my-dialog]` → `transition: opacity 0.25s ease;`
- `.my-dialog-motion-enter-active .my-dialog[data-my-dialog], .my-dialog-motion-leave-active .my-dialog[data-my-dialog]` → `transition: transform 0.25s cubic-bezier(0.2, 0.7, 0.2, 1);`
- `.my-dialog[data-my-dialog]` → `border-radius: var(--dialog-radius, 28px); width: min(var(--dialog-width, 420px), 100%); padding: var(--dialog-padding, 32px); text-align: center; max-height: calc(100dvh - 2 * var(--dialog-margin, 16px)); display: flex; flex-direction: column; overflow: hidden; background: var(--card-background); border: 0; box-shadow: var(--modal-shadow, var(--popup-shadow));`
- `.my-dialog-icon[data-my-dialog]` → `width: 59px; height: 59px; border-radius: 20px; background: var(--fill); color: var(--primary); display: grid; place-items: center; margin: 0 auto 18px;`
- `.my-dialog-icon svg[data-my-dialog]` → `width: 27px; height: 27px;`
- `.my-dialog h3[data-my-dialog]` → `font-size: 22px; font-weight: var(--font-weight-subtitle, 600); margin: 0 0 10px; overflow-wrap: anywhere;`
- `.my-dialog-body[data-my-dialog]` → `flex: 1 1 auto; min-height: 0; overflow-wrap: anywhere; overflow-y: auto; overscroll-behavior: contain; scrollbar-width: thin; scrollbar-color: var(--gray) transparent; text-align: inherit; font-size: 15px; color: var(--text-secondary); line-height: 1.9; margin: 0 0 24px;`
- `.my-dialog-body > p[data-my-dialog]` → `margin: 0 0 16px;`
- `.my-dialog-actions[data-my-dialog]` → `margin: 0 calc(-1 * var(--dialog-padding, 32px)) calc(-1 * var(--dialog-padding, 32px));`
- `.my-dialog-actions.my-custom-actions[data-my-dialog]` → `margin: 0;`
- `.my-dialog-motion-enter-active[data-my-dialog], .my-dialog-motion-leave-active[data-my-dialog], .my-dialog-motion-enter-active .my-dialog[data-my-dialog], .my-dialog-motion-leave-active .my-dialog[data-my-dialog]` → `transition: none;`

</details>

### Divider

- 契约证据：packages/vue/components/Divider.vue:1-19；核心：packages/core/my-ui.js:1682。
- Props / 变体：`{ vertical?: boolean align?: 'start' ∣ 'center' ∣ 'end' dashed?: boolean }`。
- Events：`{}`。
- 默认值：`{ align: 'center' }`。
- 核心静态插槽：default；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--divider-spacing`、`--text-secondary`、`--font-weight`、`--divider-color`、`--border`、`--divider-height`。
- 视觉证据：packages/core/my-ui.css:4103-4154（Divider）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Divider ───────────────────────────────────────────── */ .my-divider[data-my-divider]` → `display: flex; align-items: center; gap: 12px; width: 100%; margin: var(--divider-spacing, 20px) 0; color: var(--text-secondary); font-size: 13px; font-weight: var(--font-weight, 400); line-height: 1.6;`
- `/* 用零高度边框绘制，保持与列表分隔线相同的栅格取整方式。 */ .my-divider[data-my-divider]::before, .my-divider.my-labeled[data-my-divider]::after` → `content: ""; flex: 1; min-width: 0; border-block-start: 1px solid var(--divider-color, var(--border));`
- `.my-divider-label[data-my-divider]` → `flex: 0 1 auto; min-width: 0; overflow-wrap: anywhere;`
- `.my-divider.my-vertical[data-my-divider]` → `display: inline-flex; flex: 0 0 auto; width: 1px; height: var(--divider-height, 1em); margin: 0 var(--divider-spacing, 12px); vertical-align: middle;`
- `.my-divider.my-vertical[data-my-divider]::before` → `flex: none; height: 100%; border-block-start: 0; border-inline-start: 1px solid var(--divider-color, var(--border));`

</details>

### Drawer

- 契约证据：packages/vue/components/Drawer.vue:1-32；核心：packages/core/my-ui.js:3796。
- Props / 变体：`{ modelValue: boolean title: string placement?: 'left' ∣ 'right' ∣ 'top' ∣ 'bottom' swipeable?: boolean closeOnBackdrop?: boolean closeOnEscape?: boolean }`。
- Events：`{ 'update:modelValue': [value: boolean] close: [] 'after-leave': [] }`。
- 默认值：`{ placement: 'right', swipeable: true, closeOnBackdrop: true, closeOnEscape: true }`。
- 核心静态插槽：无静态 c.slot 调用；动态出口见核心实现；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--primary`、`--font-weight-action`、`--border`、`--danger`、`--press`、`--hover`、`--drawer-margin`、`--overlay-background`、`--overlay-backdrop-filter`、`--card-background`、`--text`、`--drawer-radius`、`--modal-shadow`、`--popup-shadow`、`--drawer-size`、`--font-weight-subtitle`、`--text-secondary`、`--drawer-padding`、`--gray`。
- 视觉证据：packages/core/my-ui.css:2680-2741（PopupActions）。
<details><summary>尺寸、排版、动效规格</summary>

- `button[data-my-popup-actions]` → `position: relative; width: 100%; min-width: 0; border: 0; border-radius: 0; background: transparent; color: var(--primary); font: inherit; font-size: 16px; font-weight: var(--font-weight-action, 500); line-height: 24px; padding: 18px 16px calc(24px + env(safe-area-inset-bottom, 0px)); min-height: 66px; touch-action: manipulation; transition: background-color 0.14s;`
- `/* 短线由操作区居中定位，底部延伸留白仍属于按钮点击区。 */ .my-popup-actions.my-paired[data-my-popup-actions]::after` → `content: ""; position: absolute; inset-inline-start: 50%; top: 20px; height: 20px; width: 0; border-inline-start: 1px solid var(--border); pointer-events: none;`
- `button[data-my-popup-actions]:focus-visible::after` → `content: ""; position: absolute; inset: 6px; border: 2px solid var(--primary); border-radius: 12px; pointer-events: none;`

</details>
- 视觉证据：packages/core/my-ui.css:2997-3173（Drawer）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Drawer ───────────────────────────────────────────── */ .my-drawer-overlay[data-my-drawer]` → `position: fixed; inset: 0; padding: var(--drawer-margin, 0px); display: flex; z-index: 100; isolation: isolate;`
- `.my-drawer-motion-enter-active .my-drawer-scrim[data-my-drawer], .my-drawer-motion-leave-active .my-drawer-scrim[data-my-drawer]` → `transition: opacity 0.25s ease;`
- `.my-drawer-motion-enter-active .my-drawer[data-my-drawer], .my-drawer-motion-leave-active .my-drawer[data-my-drawer]` → `transition: opacity 0.25s ease, transform 0.25s cubic-bezier(0.2, 0.7, 0.2, 1);`
- `.my-drawer[data-my-drawer]` → `position: relative; display: flex; flex-direction: column; min-width: 0; min-height: 0; background: var(--card-background); color: var(--text); border-radius: var(--drawer-radius, 0px); box-shadow: var(--modal-shadow, var(--popup-shadow)); overflow: hidden;`
- `.my-drawer-overlay[data-swipe-dismissed].my-drawer-motion-leave-active[data-my-drawer], .my-drawer-overlay[data-swipe-dismissed].my-drawer-motion-leave-active .my-drawer-scrim[data-my-drawer], .my-drawer-overlay[data-swipe-dismissed].my-drawer-motion-leave-active .my-drawer[data-my-drawer]` → `transition: none;`
- `.my-left .my-drawer[data-my-drawer], .my-right .my-drawer[data-my-drawer]` → `width: min(var(--drawer-size, 360px), 100%);`
- `.my-top .my-drawer[data-my-drawer], .my-bottom .my-drawer[data-my-drawer]` → `width: 100%; height: min(var(--drawer-size, 420px), 100%);`
- `.my-drawer-header[data-my-drawer]` → `display: flex; align-items: center; gap: 12px; min-height: 72px; flex: 0 0 auto; padding: 14px 16px 14px 24px; border-bottom: 1px solid var(--border);`
- `h3[data-my-drawer]` → `min-width: 0; margin: 0; flex: 1; font-size: 20px; font-weight: var(--font-weight-subtitle, 600); line-height: 28px; overflow-wrap: anywhere;`
- `.my-drawer-close[data-my-drawer]` → `width: 44px; height: 44px; flex-shrink: 0; display: grid; place-items: center; border: 0; background: transparent; color: var(--text-secondary); border-radius: 12px;`
- `.my-drawer-body[data-my-drawer]` → `min-height: 0; flex: 1; padding: var(--drawer-padding, 24px); overflow-y: auto; overscroll-behavior: contain; scrollbar-width: thin; scrollbar-color: var(--gray) transparent;`
- `.my-drawer-actions[data-my-drawer]` → `flex: 0 0 auto; padding: 16px 24px calc(20px + env(safe-area-inset-bottom, 0px)); border-top: 1px solid var(--border);`
- `.my-drawer-motion-enter-active[data-my-drawer], .my-drawer-motion-leave-active[data-my-drawer], .my-drawer-motion-enter-active .my-drawer-scrim[data-my-drawer], .my-drawer-motion-leave-active .my-drawer-scrim[data-my-drawer], .my-drawer-motion-enter-active .my-drawer[data-my-drawer], .my-drawer-motion-leave-active .my-drawer[data-my-drawer]` → `transition: none;`

</details>

### Empty

- 契约证据：packages/vue/components/Empty.vue:1-22；核心：packages/core/my-ui.js:2182。
- Props / 变体：`{ state?: 'empty' ∣ 'error' title?: string description?: string icon?: IconName }`。
- Events：`{}`。
- 默认值：`{ state: 'empty' }`。
- 核心静态插槽：default；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--fill`、`--text-secondary`、`--danger`、`--card-background`、`--font-weight-action`、`--text`。
- 视觉证据：packages/core/my-ui.css:3858-3907（Empty）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Empty ───────────────────────────────────────────── */ .my-empty[data-my-empty]` → `display: flex; flex-direction: column; align-items: center; justify-content: center; min-height: 218px; padding: 28px 18px; text-align: center;`
- `.my-empty-mark[data-my-empty]` → `display: grid; place-items: center; width: 58px; height: 58px; margin-bottom: 18px; border-radius: 19px; background: var(--fill); color: var(--text-secondary);`
- `.my-empty-mark svg[data-my-empty]` → `width: 28px; height: 28px;`
- `strong[data-my-empty]` → `font-size: 15px; font-weight: var(--font-weight-action, 500); color: var(--text);`
- `p[data-my-empty]` → `margin: 9px 0 0; max-width: 32ch; font-size: 13px; line-height: 1.7; color: var(--text-secondary); overflow-wrap: anywhere;`
- `.my-empty-actions[data-my-empty]` → `display: flex; justify-content: center; flex-wrap: wrap; gap: 10px; margin-top: 20px;`

</details>

### Floating

- 契约证据：packages/vue/components/Floating.vue:1-31；核心：packages/core/my-ui.js:3451。
- Props / 变体：`{ modelValue: boolean anchor?: FloatingAnchor placement?: FloatingPlacement matchWidth?: boolean motion?: 'expand' ∣ 'slide' ∣ 'fade' }`。
- Events：`{ 'update:modelValue': [value: boolean] positioned: [] 'after-leave': [] }`。
- 默认值：`{ placement: 'bottom-start', motion: 'expand' }`。
- 核心静态插槽：default、actions；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--floating-width`、`--card-background`、`--text`、`--floating-radius`、`--popup-shadow`、`--gray`、`--floating-source-x`、`--floating-source-y`、`--floating-source-height`、`--floating-dismiss-opacity`。
- 视觉证据：packages/core/my-ui.css:2389-2533（Floating）。
<details><summary>尺寸、排版、动效规格</summary>

- `.my-floating-panel[data-my-floating]` → `position: relative; width: var(--floating-width, 236px); max-width: 100%; padding: 0; background: var(--card-background); color: var(--text); border: 0; border-radius: var(--floating-radius, 17px); box-shadow: var(--popup-shadow); overflow: auto; overscroll-behavior: contain; scrollbar-width: thin; scrollbar-color: var(--gray) transparent; pointer-events: auto; scale: 1; translate: 0px 0px; transition: scale 0.22s cubic-bezier(0.18, 0.79, 0.22, 1), translate 0.22s cubic-bezier(0.18, 0.79, 0.22, 1);`
- `.my-floating-motion-enter-active[data-my-floating], .my-floating-motion-leave-active[data-my-floating]` → `transition: opacity 0.19s ease, transform 0.26s cubic-bezier(0.18, 0.79, 0.22, 1), scale 0.22s cubic-bezier(0.18, 0.79, 0.22, 1), translate 0.22s cubic-bezier(0.18, 0.79, 0.22, 1);`
- `[data-motion="slide"] .my-floating-motion-enter-active[data-my-floating], [data-motion="slide"] .my-floating-motion-leave-active[data-my-floating]` → `transition: opacity 0.17s ease, transform 0.22s cubic-bezier(0.2, 0.78, 0.22, 1), scale 0.22s cubic-bezier(0.18, 0.79, 0.22, 1), translate 0.22s cubic-bezier(0.18, 0.79, 0.22, 1);`
- `[data-motion="fade"] .my-floating-motion-enter-active[data-my-floating], [data-motion="fade"] .my-floating-motion-leave-active[data-my-floating]` → `transition: opacity 0.2s ease;`
- `.my-floating-panel[data-cascade].my-floating-motion-enter-active[data-my-floating], .my-floating-panel[data-cascade].my-floating-motion-leave-active[data-my-floating]` → `transition: transform 0.28s cubic-bezier(0.18, 0.79, 0.22, 1), clip-path 0.28s cubic-bezier(0.18, 0.79, 0.22, 1), scale 0.22s cubic-bezier(0.18, 0.79, 0.22, 1), translate 0.22s cubic-bezier(0.18, 0.79, 0.22, 1);`
- `/* 整组关闭只淡出；位置、缩放与标题裁剪由菜单保持在离场前的姿态。 */ .my-floating-panel[data-dismissing].my-floating-motion-leave-active[data-my-floating]` → `transition: opacity 0.2s ease; pointer-events: none;`
- `.my-floating-panel[data-my-floating]` → `transition: none;`

</details>

### Form

- 契约证据：packages/vue/components/Form.vue:1-16；核心：packages/core/my-ui.js:2241。
- Props / 变体：`{ layout?: FormLayout }`。
- Events：`{}`。
- 默认值：`{ layout: 'vertical' }`。
- 核心静态插槽：default；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：宿主/子组件继承，组件自身无单独 CSS 变量。
- 视觉证据：packages/core/my-ui.css:777-791（Form）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Form ───────────────────────────────────────────── */ .my-form[data-my-form]` → `display: flex; flex-direction: column; align-items: stretch; gap: 26px; min-width: 0;`

</details>

### FormField

- 契约证据：packages/vue/components/FormField.vue:1-25；核心：packages/core/my-ui.js:2257。
- Props / 变体：`{ label: string id?: string required?: boolean error?: string hint?: string group?: boolean }`。
- Events：`{}`。
- 默认值：`无显式 withDefaults，见原文件`。
- 核心静态插槽：default、hint、prefix、suffix；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--font-weight-action`、`--text-secondary`、`--danger`、`--success`。
- 视觉证据：packages/core/my-ui.css:792-875（FormField）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── FormField ───────────────────────────────────────────── */ .my-form-field[data-my-form-field]` → `min-width: 0;`
- `.my-field-label[data-my-form-field]` → `display: block; font-weight: var(--font-weight-action, 500); color: var(--text-secondary); font-size: 13px; line-height: 20px; margin-bottom: 8px;`
- `.my-field-body[data-my-form-field]` → `min-width: 0;`
- `.my-field-control[data-my-form-field]` → `position: relative; min-width: 0;`
- `.my-form-field.my-horizontal[data-my-form-field], .my-form-field.my-inline[data-my-form-field]` → `display: grid; grid-template-columns: 96px minmax(0, 1fr); column-gap: 16px; align-items: start;`
- `.my-form-field.my-inline[data-my-form-field]` → `flex: 1 1 320px; grid-template-columns: 80px minmax(0, 1fr); column-gap: 12px;`
- `.my-field-foot[data-my-form-field]` → `margin-top: 10px; display: flex; justify-content: space-between; gap: 10px; color: var(--text-secondary); font-size: 13px; line-height: 1.5; overflow-wrap: anywhere;`
- `.my-field-foot[data-my-form-field] .my-valid` → `color: var(--success); display: flex; gap: 5px; align-items: center;`
- `.my-field-foot[data-my-form-field] svg` → `width: 13px; height: 13px;`
- `.my-field-error[data-my-form-field]` → `position: absolute; top: calc(100% + 4px); left: 0; width: 100%; margin: 0; color: var(--danger); font-size: 12px; line-height: 16px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;`
- `.my-form-field.my-horizontal[data-my-form-field]` → `grid-template-columns: 80px minmax(0, 1fr); column-gap: 12px;`

</details>

### Icon

- 契约证据：packages/vue/components/Icon.vue:1-16；核心：packages/core/my-ui.js:1224。
- Props / 变体：`{ name: IconName }`。
- Events：`{}`。
- 默认值：`无显式 withDefaults，见原文件`。
- 核心静态插槽：无静态 c.slot 调用；动态出口见核心实现；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：宿主/子组件继承，组件自身无单独 CSS 变量。
- 视觉证据：packages/core/my-ui.css:152-164（Icon）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Icon ───────────────────────────────────────────── */ svg[data-my-icon]` → `width: 20px; height: 20px; flex-shrink: 0; stroke: currentColor; fill: none; stroke-width: 1.8; stroke-linecap: round; stroke-linejoin: round;`

</details>

### Image

- 契约证据：packages/vue/components/Image.vue:1-38；核心：packages/core/my-ui.js:1452。
- Props / 变体：`{ src?: string alt?: string width?: number ∣ string height?: number ∣ string ratio?: number ∣ string fit?: 'cover' ∣ 'contain' ∣ 'fill' ∣ 'none' ∣ 'scale-down' loading?: 'lazy' ∣ 'eager' }`。
- Events：`{ load: [event: Event] error: [event: Event] }`。
- 默认值：`{ alt: '', fit: 'cover', loading: 'lazy' }`。
- 核心静态插槽：无静态 c.slot 调用；动态出口见核心实现；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--image-natural-ratio`、`--image-radius`、`--image-background`、`--fill`、`--text-secondary`、`--image-position`。
- 视觉证据：packages/core/my-ui.css:3381-3448（Image）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Image ───────────────────────────────────────────── */ /* 默认预留 4:3 占位，成功后采用图片自身比例；显式宽高或 aspect-ratio 优先。 */ .my-image[data-my-image]` → `position: relative; container: my-image / inline-size; display: block; width: 100%; max-width: 100%; aspect-ratio: var(--image-natural-ratio, 4 / 3); overflow: hidden; border-radius: var(--image-radius, 12px); background: var(--image-background, var(--fill)); color: var(--text-secondary);`
- `.my-image-content[data-my-image]` → `position: absolute; inset: 0; display: block; width: 100%; height: 100%; object-position: var(--image-position, 50% 50%); opacity: 0; transition: opacity 0.2s ease;`
- `.my-image-placeholder[data-my-image], .my-image-error[data-my-image]` → `position: absolute; inset: 0; display: grid; place-items: center; padding: 12px; font-size: 13px; line-height: 20px; text-align: center;`
- `.my-image-message[data-my-image]` → `display: flex; flex-direction: column; align-items: center; gap: 8px;`
- `.my-image-message[data-my-image] > svg` → `width: 28px; height: 28px;`
- `.my-image-error[data-my-image] .my-button` → `min-height: 36px; margin-top: -4px; font-size: 13px;`
- `.my-image-placeholder[data-my-image], .my-image-error[data-my-image]` → `padding: 0;`
- `.my-image-error[data-my-image] .my-button` → `width: 32px; min-height: 32px; margin: 0; padding: 0;`

</details>

### ImagePreview

- 契约证据：packages/vue/components/ImagePreview.vue:1-35；核心：packages/core/my-ui.js:3809。
- Props / 变体：`{ modelValue: boolean images: readonly (string ∣ ImagePreviewItem)[] startIndex?: number title?: string maxZoom?: number closeOnEscape?: boolean }`。
- Events：`{ 'update:modelValue': [value: boolean] 'index-change': [index: number] close: [] 'after-leave': [] }`。
- 默认值：`{ startIndex: 0, title: '图片预览', maxZoom: 4, closeOnEscape: true }`。
- 核心静态插槽：item；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--text`、`--image-preview-background`、`--text-secondary`、`--press`、`--hover`。
- 视觉证据：packages/core/my-ui.css:3449-3598（ImagePreview）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── ImagePreview ────────────────────────────────────── */ .my-image-preview-overlay[data-my-image-preview]` → `--image-radius: 0px; --image-background: transparent; --text: #f7f8fa; --text-secondary: #bdc3cd; --primary: #e2eaff; --primary-text: #111318; --hover: rgb(255 255 255 / .12); --press: rgb(255 255 255 / .2); position: fixed; inset: 0; overflow: hidden; color: var(--text); background: var(--image-preview-background, #111318); color-scheme: dark; overscroll-behavior: contain;`
- `.my-image-preview[data-my-image-preview]` → `position: relative; display: grid; grid-template-rows: auto minmax(0, 1fr) auto; width: 100%; height: 100%; overflow: hidden; outline: none;`
- `.my-image-preview-header[data-my-image-preview]` → `margin: 0; display: flex; align-items: center; gap: 20px; min-height: 72px; padding: calc(12px + env(safe-area-inset-top, 0px)) max(24px, env(safe-area-inset-right, 0px)) 12px max(24px, env(safe-area-inset-left, 0px));`
- `.my-image-preview-title[data-my-image-preview]` → `flex: 1; min-width: 0; margin: 0; font-size: 16px; line-height: 1.5; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;`
- `.my-image-preview-count[data-my-image-preview], .my-image-preview-zoom[data-my-image-preview]` → `color: var(--text-secondary); font-size: 13px; font-variant-numeric: tabular-nums; white-space: nowrap;`
- `.my-image-preview-viewport[data-my-image-preview]` → `position: relative; min-width: 0; min-height: 0; overflow: hidden; touch-action: none; user-select: none; -webkit-user-select: none;`
- `.my-image-preview-slide[data-my-image-preview]` → `position: absolute; inset: 0; transition: transform 220ms cubic-bezier(.2, .7, .2, 1);`
- `.my-image-preview-slide > .my-image[data-my-image-preview]` → `transform-origin: center; transition: transform 180ms ease-out;`
- `.my-image-preview-viewport.my-dragging .my-image-preview-slide[data-my-image-preview], .my-image-preview-viewport.my-dragging .my-image[data-my-image-preview]` → `transition: none;`
- `.my-image-preview-empty[data-my-image-preview]` → `display: grid; place-items: center; height: 100%; color: var(--text-secondary); font-size: 14px;`
- `.my-image-preview-button[data-my-image-preview]` → `display: inline-flex; align-items: center; justify-content: center; flex: none; width: 44px; height: 44px; padding: 0; border: 1px solid rgb(255 255 255 / .1); border-radius: 50%; background: rgb(255 255 255 / .06); color: var(--text); touch-action: manipulation; transition: background 140ms, opacity 140ms;`
- `.my-image-preview-button[data-my-image-preview] svg` → `width: 20px; height: 20px;`
- `.my-image-preview-footer[data-my-image-preview]` → `margin: 0; display: grid; justify-items: center; gap: 14px; padding: 20px max(16px, env(safe-area-inset-right, 0px)) calc(20px + env(safe-area-inset-bottom, 0px)) max(16px, env(safe-area-inset-left, 0px));`
- `.my-image-preview-caption[data-my-image-preview]` → `max-width: 100%; margin: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: var(--text-secondary); font-size: 13px; line-height: 20px;`
- `.my-image-preview-toolbar[data-my-image-preview]` → `display: flex; align-items: center; gap: 10px;`
- `.my-image-preview-zoom[data-my-image-preview]` → `min-width: 46px; text-align: center;`
- `.my-image-preview-motion-enter-active[data-my-image-preview], .my-image-preview-motion-leave-active[data-my-image-preview]` → `transition: opacity 180ms ease;`
- `.my-image-preview-header[data-my-image-preview]` → `min-height: 64px; gap: 12px; padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(12px, env(safe-area-inset-right, 0px));`
- `.my-image-preview-footer[data-my-image-preview]` → `padding-top: 14px; padding-bottom: calc(14px + env(safe-area-inset-bottom, 0px)); gap: 10px;`
- `.my-image-preview-overlay[data-my-image-preview], .my-image-preview-overlay [data-my-image-preview]` → `transition: none;`

</details>

### Input

- 契约证据：packages/vue/components/Input.vue:1-47；核心：packages/core/my-ui.js:2434。
- Props / 变体：`{ modelValue: string label: string id?: string type?: 'text' ∣ 'search' ∣ 'email' ∣ 'password' ∣ 'tel' ∣ 'url' passwordToggle?: boolean placeholder?: string icon?: IconName clearable?: boolean maxlength?: number disabled?: boolean readonly?: boolean required?: boolean error?: string hint?: string autocomplete?: string }`。
- Events：`{ 'update:modelValue': [value: string] }`。
- 默认值：`{ placeholder: '', type: 'text', autocomplete: 'off' }`。
- 核心静态插槽：无静态 c.slot 调用；动态出口见核心实现；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--input-height`、`--input-padding`、`--input-border-color`、`--input-radius`、`--input-background`、`--fill`、`--text-secondary`、`--input-focus-color`、`--primary`、`--danger`、`--input-color`、`--text`、`--press`、`--hover`。
- 视觉证据：packages/core/my-ui.css:876-1007（Input）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Input ───────────────────────────────────────────── */ /* 八个外观变量分别控制底色、文字、边框整体/颜色、焦点色、高度、圆角和内边距。 */ .my-input-box[data-my-input]` → `box-sizing: border-box; width: 100%; display: flex; align-items: center; gap: 8px; height: var(--input-height, 44px); padding-inline: var(--input-padding, 13px); border: var( --input-border, 1.5px solid var(--input-border-color, transparent) ); border-radius: var(--input-radius, 12px); background: var(--input-background, var(--fill)); color: var(--text-secondary); transition: border-color 0.16s ease, background-color 0.16s ease;`
- `.my-input-box[data-my-input] svg` → `width: 16px; height: 16px; flex-shrink: 0;`
- `.my-input-prefix[data-my-input]` → `display: flex; align-items: center; gap: 8px; flex-shrink: 0;`
- `.my-input-box input[data-my-input]` → `width: 100%; height: 100%; min-width: 0; padding: 0; border: 0; outline: 0; background: none; color: var(--input-color, var(--text)); font-size: inherit;`
- `/* 图标盒与文字共享边距；尾部留白由最后一项接管，扩展热区而不放大圆形反馈。 */ .my-input-actions[data-my-input]` → `display: flex; align-items: stretch; align-self: stretch; flex-shrink: 0; gap: 0; margin-inline-end: calc(-1 * var(--input-padding, 13px));`
- `.my-input-suffix[data-my-input]` → `display: flex; align-items: center; justify-content: center; gap: 8px; min-width: 24px; flex-shrink: 0; padding-inline: 4px;`
- `.my-input-action[data-my-input]` → `display: flex; align-items: center; justify-content: center; min-width: 24px; flex-shrink: 0; padding: 0; border: 0; border-radius: 0; background: transparent; color: var(--text-secondary); transform: none;`
- `.my-input-action-visual[data-my-input]` → `display: grid; place-items: center; width: 24px; height: 24px; flex-shrink: 0; border-radius: 50%; background: transparent; pointer-events: none; transition: background-color 0.15s ease;`

</details>

### ListRow

- 契约证据：packages/vue/components/ListRow.vue:1-34；核心：packages/core/my-ui.js:2652。
- Props / 变体：`{ title: string description?: string value?: string toggle?: boolean modelValue?: boolean disabled?: boolean delayTouchDown?: number delayTouchUp?: number }`。
- Events：`{ click: [event: MouseEvent] 'update:modelValue': [value: boolean] }`。
- 默认值：`{ delayTouchDown: 0, delayTouchUp: 100 }`。
- 核心静态插槽：leading、trailing；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--fill`、`--primary`、`--list-padding-block`、`--list-padding-inline`、`--text`、`--font-weight-action`、`--list-divider-color`、`--border`、`--font-weight`、`--text-secondary`、`--hover`、`--press`。
- 视觉证据：packages/core/my-ui.css:1809-1956（ListRow）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── ListRow ───────────────────────────────────────────── */ .my-leading-content[data-my-list-row]` → `width: 32px; height: 32px; display: grid; place-items: center; flex-shrink: 0; border-radius: 10px; background: var(--fill); color: var(--primary);`
- `.my-leading-content[data-my-list-row] svg` → `width: 18px; height: 18px;`
- `.my-trailing-content[data-my-list-row]` → `display: inline-flex; align-items: center; gap: 6px; flex-shrink: 0; margin-left: auto;`
- `.my-list-row[data-my-list-row]` → `display: flex; align-items: center; gap: 12px; /* 容器提供默认间距，行上的局部变量可覆写；普通列表保持原有尺寸。 */ padding: var(--list-padding-block, 14px) var(--list-padding-inline, 16px); position: relative; min-width: 0; color: var(--text); font-size: 15px; font-weight: var(--font-weight-action, 500); transition: background-color 0.14s ease; -webkit-tap-highlight-color: transparent;`
- `/* 绝对定位边框不占布局，并使用浏览器的物理像素取整来统一细线厚度。 */ .my-list-row + .my-list-row[data-my-list-row]::before` → `content: ""; position: absolute; top: 0; left: var(--list-padding-inline, 16px); right: var(--list-padding-inline, 16px); height: 0; border-top: 1px solid var(--list-divider-color, var(--border)); pointer-events: none;`
- `.my-list-row[data-my-list-row]:focus-visible::after` → `content: ""; position: absolute; inset: 4px 6px; border: 2px solid var(--primary); border-radius: 10px; pointer-events: none;`
- `.my-list-row-copy[data-my-list-row]` → `min-width: 0; flex: 1; overflow-wrap: anywhere;`
- `.my-list-row-copy strong[data-my-list-row]` → `display: block; font-size: inherit; line-height: 22px; color: inherit; font-weight: inherit;`
- `.my-list-row-copy small[data-my-list-row]` → `display: block; margin-top: 4px; font-size: 14px; font-weight: var(--font-weight, 400); line-height: 20px; color: var(--text-secondary);`
- `.my-list-action[data-my-list-row]` → `width: 100%; background: transparent; border: 0; text-align: left; color: var(--text); cursor: pointer; touch-action: manipulation;`
- `.my-list-action svg.my-trailing-icon[data-my-list-row]` → `width: 18px; height: 18px; transition: transform 0.22s ease; transform: none; color: var(--text-secondary);`
- `.my-list-selected-value[data-my-list-row]` → `font-size: 14px; font-weight: var(--font-weight, 400); color: var(--text-secondary); line-height: 20px; text-align: right; overflow-wrap: anywhere; max-width: min(40%, 160px); flex: 0 1 auto; margin-left: auto;`
- `.my-list-row[data-my-list-row]` → `transition: background-color 160ms cubic-bezier(0.215, 0.61, 0.355, 1);`

</details>

### Loading

- 契约证据：packages/vue/components/Loading.vue:1-17；核心：packages/core/my-ui.js:1377。
- Props / 变体：`{ size?: 'small' ∣ 'medium' ∣ 'large' label?: string }`。
- Events：`{}`。
- 默认值：`{ size: 'medium', label: '加载中' }`。
- 核心静态插槽：default；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：宿主/子组件继承，组件自身无单独 CSS 变量。
- 视觉证据：packages/core/my-ui.css:3755-3806（Loading）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Loading ───────────────────────────────────────────── */ .my-loading[data-my-loading]` → `display: inline-flex; align-items: center; justify-content: center; gap: 9px; color: inherit; font-size: 24px;`
- `.my-loading.my-small[data-my-loading]` → `font-size: 16px;`
- `.my-loading.my-large[data-my-loading]` → `font-size: 32px;`
- `.my-spinner[data-my-loading]` → `width: 1em; height: 1em; flex-shrink: 0; fill: none; stroke: currentColor; stroke-width: 2.5; stroke-linecap: round; stroke-dasharray: 42 16; animation: my-spin-data-my-loading 0.8s linear infinite;`
- `.my-loading-text[data-my-loading]` → `font-size: 13px; line-height: 1.5;`
- `.my-sr-only[data-my-loading], .my-sr-only[data-my-steps]` → `position: absolute; width: 1px; height: 1px; padding: 0; overflow: hidden; clip-path: inset(50%); white-space: nowrap;`
- `.my-spinner[data-my-loading]` → `animation: none;`

</details>

### Menu

- 契约证据：packages/vue/components/Menu.vue:1-49；核心：packages/core/my-ui.js:4952。
- Props / 变体：`{ options: MenuOption[] label?: string modelValue?: string ∣ string[] mode?: ListMode open?: boolean trigger?: 'click' ∣ 'contextmenu' anchor?: 'pointer' ∣ 'element' placement?: FloatingPlacement matchWidth?: boolean motion?: 'expand' ∣ 'slide' disabled?: boolean closeOnSelect?: boolean hoverDelay?: number }`。
- Events：`{ 'update:modelValue': [value: string ∣ string[]] 'update:open': [value: boolean] select: [item: MenuOption] }`。
- 默认值：`{ label: '菜单', mode: 'normal', trigger: 'click', anchor: 'pointer', placement: 'bottom-start', open: undefined, closeOnSelect: undefined, hoverDelay: 200 }`。
- 核心静态插槽：default；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--floating-width`、`--card-background`、`--text`、`--floating-radius`、`--popup-shadow`、`--gray`、`--floating-source-x`、`--floating-source-y`、`--floating-source-height`、`--floating-dismiss-opacity`、`--list-padding-block`、`--text-secondary`、`--primary`、`--list-padding-inline`、`--list-divider-color`、`--border`。
- 视觉证据：packages/core/my-ui.css:2389-2533（Floating）。
<details><summary>尺寸、排版、动效规格</summary>

- `.my-floating-panel[data-my-floating]` → `position: relative; width: var(--floating-width, 236px); max-width: 100%; padding: 0; background: var(--card-background); color: var(--text); border: 0; border-radius: var(--floating-radius, 17px); box-shadow: var(--popup-shadow); overflow: auto; overscroll-behavior: contain; scrollbar-width: thin; scrollbar-color: var(--gray) transparent; pointer-events: auto; scale: 1; translate: 0px 0px; transition: scale 0.22s cubic-bezier(0.18, 0.79, 0.22, 1), translate 0.22s cubic-bezier(0.18, 0.79, 0.22, 1);`
- `.my-floating-motion-enter-active[data-my-floating], .my-floating-motion-leave-active[data-my-floating]` → `transition: opacity 0.19s ease, transform 0.26s cubic-bezier(0.18, 0.79, 0.22, 1), scale 0.22s cubic-bezier(0.18, 0.79, 0.22, 1), translate 0.22s cubic-bezier(0.18, 0.79, 0.22, 1);`
- `[data-motion="slide"] .my-floating-motion-enter-active[data-my-floating], [data-motion="slide"] .my-floating-motion-leave-active[data-my-floating]` → `transition: opacity 0.17s ease, transform 0.22s cubic-bezier(0.2, 0.78, 0.22, 1), scale 0.22s cubic-bezier(0.18, 0.79, 0.22, 1), translate 0.22s cubic-bezier(0.18, 0.79, 0.22, 1);`
- `[data-motion="fade"] .my-floating-motion-enter-active[data-my-floating], [data-motion="fade"] .my-floating-motion-leave-active[data-my-floating]` → `transition: opacity 0.2s ease;`
- `.my-floating-panel[data-cascade].my-floating-motion-enter-active[data-my-floating], .my-floating-panel[data-cascade].my-floating-motion-leave-active[data-my-floating]` → `transition: transform 0.28s cubic-bezier(0.18, 0.79, 0.22, 1), clip-path 0.28s cubic-bezier(0.18, 0.79, 0.22, 1), scale 0.22s cubic-bezier(0.18, 0.79, 0.22, 1), translate 0.22s cubic-bezier(0.18, 0.79, 0.22, 1);`
- `/* 整组关闭只淡出；位置、缩放与标题裁剪由菜单保持在离场前的姿态。 */ .my-floating-panel[data-dismissing].my-floating-motion-leave-active[data-my-floating]` → `transition: opacity 0.2s ease; pointer-events: none;`
- `.my-floating-panel[data-my-floating]` → `transition: none;`

</details>
- 视觉证据：packages/core/my-ui.css:2534-2667（MenuPanel）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── MenuPanel ───────────────────────────────────────────── */ .my-menu-panel-content[data-my-menu-panel], .my-menu-list[data-my-menu-panel]` → `padding: 0; margin: 0; outline: none; transition-property: none;`
- `.my-menu-panel-content[data-my-menu-panel]` → `position: relative; border-radius: inherit;`
- `/* 容器不参与过渡，避免减少动态效果规则让继承的 visibility 延后一帧。 */ .my-menu-level[data-my-menu-panel]` → `position: relative; border-radius: inherit; overflow: clip; background: var(--card-background); transition-property: none;`
- `.my-menu-list[data-my-menu-panel]:focus-visible` → `outline: 2px solid var(--primary); outline-offset: -6px; border-radius: var(--floating-radius, 17px);`
- `.my-menu-check[data-my-menu-panel]` → `width: 17px; height: 17px; color: var(--primary); visibility: hidden;`
- `.my-menu-chevron[data-my-menu-panel]` → `width: 17px; height: 17px; color: inherit;`
- `.my-menu-panel-content[data-my-menu-panel] .my-leading-content` → `width: 20px; height: 20px; border-radius: 0; background: transparent; color: inherit;`
- `.my-menu-panel-content[data-my-menu-panel] .my-leading-content svg` → `width: 20px; height: 20px;`
- `.my-menu-return-chevron[data-my-menu-panel]` → `width: 17px; height: 17px; color: var(--primary);`
- `.my-menu-parent-return[data-my-menu-panel]` → `position: absolute; left: 0; z-index: 2; width: 100%; margin: 0; padding: 0; border: 0; border-radius: inherit; background: color-mix(in srgb, var(--card-background) 48%, transparent); cursor: pointer; touch-action: none;`
- `.my-menu-return-enter-active[data-my-menu-panel], .my-menu-return-leave-active[data-my-menu-panel]` → `transition: opacity 0.22s ease;`
- `.my-menu-return-enter-active[data-my-menu-panel], .my-menu-return-leave-active[data-my-menu-panel]` → `transition: none;`

</details>
- 视觉证据：packages/core/my-ui.css:2668-2673（Menu）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Menu ───────────────────────────────────────────── */ .my-menu-host[data-my-menu]` → `min-width: 0;`

</details>

### Navigation

- 契约证据：packages/vue/components/Navigation.vue:1-23；核心：packages/core/my-ui.js:2926。
- Props / 变体：`{ modelValue: string options: Option[] label?: string }`。
- Events：`{ 'update:modelValue': [value: string] }`。
- 默认值：`无显式 withDefaults，见原文件`。
- 核心静态插槽：无静态 c.slot 调用；动态出口见核心实现；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--fill`、`--border`、`--text-secondary`、`--primary`、`--font-weight-action`。
- 视觉证据：packages/core/my-ui.css:2127-2183（Navigation）。
<details><summary>尺寸、排版、动效规格</summary>

- `.my-navigation:is([data-my-navigation], [data-my-tabbar])` → `background: var(--fill); border: 1px solid var(--border); display: flex; justify-content: space-between; gap: 4px; height: 56px; min-height: 56px; padding: 3px 5px; border-radius: 15px; align-items: stretch;`
- `.my-navigation button:is([data-my-navigation], [data-my-tabbar])` → `min-width: 0; flex: 1; border: none; background: transparent; display: flex; align-items: center; justify-content: center; flex-direction: column; color: var(--text-secondary); opacity: 1; transform: none; touch-action: manipulation; transition: opacity 0.2s ease, color 0.15s ease; height: 100%; min-height: 0; padding: 3px 4px; gap: 2px; border-radius: 10px; font-size: 12px; line-height: 1.15;`
- `.my-navigation button svg:is([data-my-navigation], [data-my-tabbar])` → `height: 24px; width: 24px;`

</details>

### Notice

- 契约证据：packages/vue/components/Notice.vue:1-31；核心：packages/core/my-ui.js:1914。
- Props / 变体：`{ modelValue?: boolean type?: 'info' ∣ 'success' ∣ 'warning' ∣ 'error' title?: string message?: string closable?: boolean icon?: IconName ∣ false }`。
- Events：`{ 'update:modelValue': [value: boolean] close: [event: MouseEvent] }`。
- 默认值：`{ modelValue: true, type: 'info', title: '', message: '', closable: false, icon: undefined }`。
- 核心静态插槽：default、actions；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--primary`、`--success`、`--warning`、`--danger`、`--notice-color`、`--notice-radius`、`--card-background`、`--text`、`--font-weight-subtitle`、`--text-secondary`。
- 视觉证据：packages/core/my-ui.css:4020-4038（Notice）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Notice ────────────────────────────────────────────── */ .my-notice[data-my-notice]` → `--notice-color: var(--primary); display: grid; grid-template-rows: 1fr; min-width: 0; opacity: 1; transition: grid-template-rows 200ms ease, opacity 200ms ease;`
- `.my-notice-clip[data-my-notice]` → `min-height: 0; overflow: hidden;`
- `.my-notice-box[data-my-notice]` → `display: flex; align-items: flex-start; gap: 10px; padding: 13px 14px; border: 1px solid color-mix(in srgb, var(--notice-color) 18%, transparent); border-radius: var(--notice-radius, 12px); background: color-mix(in srgb, var(--notice-color) 7%, var(--card-background)); color: var(--text);`
- `.my-notice-icon[data-my-notice]` → `display: flex; align-items: center; flex: 0 0 20px; height: 22px; color: var(--notice-color);`
- `.my-notice-icon svg[data-my-notice]` → `width: 20px; height: 20px;`
- `.my-notice-body[data-my-notice]` → `flex: 1; min-width: 0; font-size: 13px; line-height: 1.7; overflow-wrap: anywhere;`
- `.my-notice-title[data-my-notice]` → `display: block; font-size: 13px; font-weight: var(--font-weight-subtitle, 600);`
- `.my-notice-actions[data-my-notice]` → `display: flex; align-items: center; flex: 0 0 auto; min-height: 22px; gap: 4px;`
- `.my-notice-close[data-my-notice]` → `width: 26px; height: 26px; margin: -2px -4px -2px 0; border-radius: 50%; color: var(--text-secondary);`
- `.my-notice-close svg[data-my-notice]` → `width: 16px; height: 16px;`

</details>

### Picker

- 契约证据：packages/vue/components/Picker.vue:1-29；核心：packages/core/my-ui.js:6294。
- Props / 变体：`{ modelValue?: T options?: readonly PickerOption[] columns?: readonly (readonly PickerOption[])[] label?: string columnLabels?: readonly string[] disabled?: boolean }`。
- Events：`{ 'update:modelValue': [value: T] }`。
- 默认值：`{ options: () => [], label: '选择', columnLabels: () => [], disabled: false }`。
- 核心静态插槽：无静态 c.slot 调用；动态出口见核心实现；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--text`、`--text-secondary`、`--picker-height`、`--picker-item-height`、`--picker-radius`、`--primary`、`--fill`、`--picker-position`、`--font-weight-subtitle`。
- 视觉证据：packages/core/my-ui.css:1426-1509（Picker）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Picker ────────────────────────────────────────────────── */ /* 修改行高和窗口高度即可调整密度，文字、选中区与动画共用同一套几何。 */ .my-picker[data-my-picker]` → `display: flex; gap: 8px; min-width: 0; color: var(--text);`
- `.my-picker-column[data-my-picker]` → `flex: 1; min-width: 0;`
- `.my-picker-column-title[data-my-picker]` → `min-height: 18px; margin-bottom: 8px; color: var(--text-secondary); font-size: 12px; line-height: 18px; text-align: center;`
- `.my-picker-wheel[data-my-picker]` → `position: relative; height: var(--picker-height, 220px); min-height: var(--picker-item-height, 44px); overflow: hidden; border-radius: var(--picker-radius, 10px); outline: none; cursor: grab; touch-action: none; user-select: none; -webkit-user-select: none;`
- `.my-picker-selection[data-my-picker]` → `position: absolute; top: 50%; right: 2px; left: 2px; height: var(--picker-item-height, 44px); translate: 0 -50%; border-radius: calc(var(--picker-radius, 10px) - 2px); background: var(--fill); pointer-events: none;`
- `.my-picker-option[data-my-picker]` → `display: flex; align-items: center; justify-content: center; height: var(--picker-item-height, 44px); padding: 0 10px; color: var(--text-secondary); font-size: 16px; line-height: 1.4;`
- `.my-picker-empty[data-my-picker]` → `display: flex; align-items: center; justify-content: center; height: 100%; color: var(--text-secondary); font-size: 13px;`

</details>

### Popover

- 契约证据：packages/vue/components/Popover.vue:1-23；核心：packages/core/my-ui.js:4982。
- Props / 变体：`{ modelValue: string label: string options: Option[] }`。
- Events：`{ 'update:modelValue': [value: string] }`。
- 默认值：`无显式 withDefaults，见原文件`。
- 核心静态插槽：无静态 c.slot 调用；动态出口见核心实现；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--popover-trigger-border`。
- 视觉证据：packages/core/my-ui.css:2674-2679（Popover）。
<details><summary>尺寸、排版、动效规格</summary>


</details>

### Popup

- 契约证据：packages/vue/components/Popup.vue:1-14；核心：packages/core/my-ui.js:7495。
- Props / 变体：`{}`。
- Events：`{}`。
- 默认值：`无显式 withDefaults，见原文件`。
- 核心静态插槽：无静态 c.slot 调用；动态出口见核心实现；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：宿主/子组件继承，组件自身无单独 CSS 变量。
- 视觉规格：Popup 本身仅承载插槽/API 宿主，实际由 Dialog/Sheet/Drawer 等绘制，packages/core/my-ui.js:7495。

### Progress

- 契约证据：packages/vue/components/Progress.vue:1-27；核心：packages/core/my-ui.js:5721。
- Props / 变体：`{ value?: number buffer?: number max?: number type?: 'line' ∣ 'circle' status?: 'normal' ∣ 'success' ∣ 'warning' ∣ 'error' label?: string showText?: boolean }`。
- Events：`{}`。
- 默认值：`{ max: 100, type: 'line', status: 'normal', label: '进度', showText: true }`。
- 核心静态插槽：default；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--progress-thickness`、`--progress-track`、`--fill`、`--progress-start-ratio`、`--progress-ratio`、`--progress-buffer-ratio`、`--primary`、`--progress-color`、`--progress-state-color`、`--font-weight`、`--success`、`--warning`、`--danger`、`--text-secondary`、`--progress-size`、`--text`、`--font-weight-action`。
- 视觉证据：packages/core/my-ui.css:1596-1651（ProgressTrack）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── ProgressTrack ───────────────────────────────────────────── */ .my-progress-track[data-my-progress-track]` → `position: relative; flex: 1; min-width: 0; height: var(--progress-thickness, 6px); overflow: hidden; border-radius: 999px; background: var(--progress-track, var(--fill));`
- `.my-progress-fill[data-my-progress-track], .my-progress-buffer[data-my-progress-track]` → `position: absolute; inset: 0 auto 0 0; height: 100%; border-radius: inherit; transition: width 0.2s ease;`
- `.my-progress-fill[data-my-progress-track]` → `left: calc(var(--progress-start-ratio) * 100%); width: calc((var(--progress-ratio) - var(--progress-start-ratio)) * 100%); background: currentColor;`
- `.my-progress-buffer[data-my-progress-track]` → `width: calc(var(--progress-buffer-ratio) * 100%); background: var( --progress-buffer-color, color-mix(in srgb, currentColor 28%, var(--progress-track, var(--fill))) );`
- `/* 拖动时即时跟随圆块，避免进度轨道追赶滑块。 */ .my-is-instant > span[data-my-progress-track]` → `transition: none;`
- `.my-is-indeterminate .my-progress-fill[data-my-progress-track]` → `width: 32%; transform: translateX(-110%); animation: my-progress-travel-data-my-progress-track 1.4s ease-in-out infinite;`
- `.my-progress-fill[data-my-progress-track], .my-progress-buffer[data-my-progress-track]` → `transition: none;`
- `.my-is-indeterminate .my-progress-fill[data-my-progress-track]` → `animation: none; transform: translateX(100%);`

</details>
- 视觉证据：packages/core/my-ui.css:1652-1761（Progress）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Progress ───────────────────────────────────────────── */ .my-progress[data-my-progress]` → `--progress-state-color: var(--primary); min-width: 0; color: var(--progress-color, var(--progress-state-color)); font-size: 13px; font-weight: var(--font-weight, 400); line-height: 1.6;`
- `.my-progress.my-line[data-my-progress]` → `display: flex; align-items: center; gap: 12px; width: 100%;`
- `.my-progress-text[data-my-progress]` → `display: inline-flex; flex: 0 0 auto; align-items: center; justify-content: center; min-width: 42px; min-height: 21px; color: var(--text-secondary); white-space: nowrap; font-variant-numeric: tabular-nums;`
- `.my-progress-text[data-my-progress] svg` → `width: 18px; height: 18px; color: var(--progress-color, var(--progress-state-color));`
- `.my-progress.my-circle[data-my-progress]` → `display: inline-grid; position: relative; width: var(--progress-size, 96px); height: var(--progress-size, 96px); vertical-align: middle;`
- `.my-progress-ring[data-my-progress]` → `display: block; width: 100%; height: 100%; fill: none; stroke-width: var(--progress-thickness, 6px); transform: rotate(-90deg);`
- `.my-ring-fill[data-my-progress], .my-ring-buffer[data-my-progress]` → `stroke-linecap: round; transition: stroke-dasharray 0.2s ease, opacity 0.2s ease;`
- `.my-circle .my-progress-text[data-my-progress]` → `position: absolute; inset: 0; min-width: 0; color: var(--text); font-size: 16px; font-weight: var(--font-weight-action, 500);`
- `.my-circle .my-progress-text[data-my-progress] svg` → `width: 28%; height: 28%;`
- `.my-circle.my-indeterminate .my-progress-text[data-my-progress]` → `font-size: 12px; font-weight: var(--font-weight, 400);`
- `.my-circle.my-indeterminate .my-ring-value[data-my-progress]` → `transform-origin: 50px 50px; animation: my-progress-rotate-data-my-progress 1s linear infinite;`
- `.my-ring-fill[data-my-progress], .my-ring-buffer[data-my-progress]` → `transition: none;`
- `.my-circle.my-indeterminate .my-ring-value[data-my-progress]` → `animation: none;`

</details>

### PullRefresh

- 契约证据：packages/vue/components/PullRefresh.vue:1-25；核心：packages/core/my-ui.js:1742。
- Props / 变体：`{ modelValue?: boolean disabled?: boolean label?: string }`。
- Events：`{ 'update:modelValue': [value: boolean] refresh: [] }`。
- 默认值：`{ modelValue: false, disabled: false, label: '下拉刷新' }`。
- 核心静态插槽：default；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--card-background`、`--text-secondary`、`--primary`。
- 视觉证据：packages/core/my-ui.css:3930-4019（PullRefresh）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── PullRefresh ───────────────────────────────────────── */ .my-pull-refresh` → `position: relative; min-height: 0; overflow: hidden; isolation: isolate; background: var(--card-background);`
- `.my-pull-refresh-viewport` → `height: 100%; overflow: auto; overscroll-behavior-y: none; -webkit-overflow-scrolling: touch;`
- `.my-pull-refresh-track` → `display: flow-root; min-height: 100%;`
- `.my-pull-refresh-indicator` → `position: absolute; z-index: 1; inset: -64px 0 auto; display: flex; align-items: center; justify-content: center; gap: 9px; height: 64px; color: var(--text-secondary); background: var(--card-background); font-size: 13px; line-height: 20px; pointer-events: none; user-select: none;`
- `.my-pull-refresh-symbol` → `display: grid; place-items: center; width: 20px; height: 20px; color: var(--primary);`
- `.my-pull-refresh-symbol > svg` → `width: 18px; height: 18px; transform: rotate(90deg); transition: transform 160ms ease;`
- `.my-pull-refresh-spinner` → `display: none; width: 18px; height: 18px; border: 2px solid color-mix(in srgb, currentColor 20%, transparent); border-top-color: currentColor; border-radius: 50%;`
- `.my-pull-refresh[data-state="refreshing"] > .my-pull-refresh-indicator > .my-pull-refresh-symbol > .my-pull-refresh-spinner` → `display: block; animation: my-pull-refresh-spin 800ms linear infinite;`
- `.my-pull-refresh[data-animated] > .my-pull-refresh-viewport > .my-pull-refresh-track, .my-pull-refresh[data-animated] > .my-pull-refresh-indicator` → `transition: transform 260ms cubic-bezier(.2, .8, .2, 1), opacity 260ms ease;`
- `.my-pull-refresh-spinner` → `animation: none !important;`
- `.my-pull-refresh-track, .my-pull-refresh-indicator, .my-pull-refresh-symbol > svg` → `transition: none !important;`

</details>

### Radio

- 契约证据：packages/vue/components/Radio.vue:1-28；核心：共享注册/帮助函数，见对应 Vue useNative 调用。
- Props / 变体：`{ modelValue?: string value: string label?: string description?: string disabled?: boolean name?: string }`。
- Events：`{ 'update:modelValue': [value: string] }`。
- 默认值：`无显式 withDefaults，见原文件`。
- 核心静态插槽：无静态 c.slot 调用；动态出口见核心实现；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--choice-size`、`--gray`、`--card-background`、`--primary`、`--primary-text`、`--text`、`--font-weight-action`、`--text-secondary`、`--font-weight`、`--list-padding-block`、`--list-padding-inline`、`--hover`、`--press`。
- 视觉证据：packages/core/my-ui.css:582-711（ChoiceControl）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── ChoiceControl ───────────────────────────────────────────── */ .my-choice-control[data-my-choice-control]` → `display: inline-flex; align-items: center; gap: 11px; min-width: 0; min-height: 42px; padding: 7px 8px; border-radius: 10px; cursor: pointer; user-select: none; -webkit-user-select: none; -webkit-tap-highlight-color: transparent; touch-action: manipulation; transition: background-color 0.14s ease;`
- `input[data-my-choice-control]` → `appearance: none; -webkit-appearance: none; display: grid; place-items: center; flex: 0 0 var(--choice-size, 20px); width: var(--choice-size, 20px); height: var(--choice-size, 20px); margin: 0; border: 1.5px solid var(--gray); border-radius: 6px; background: var(--card-background); cursor: inherit; transition: background-color 0.15s ease, border-color 0.15s ease;`
- `input[type="radio"][data-my-choice-control]` → `border-radius: 50%;`
- `input[type="radio"][data-my-choice-control]:checked::after` → `content: ""; width: 7px; height: 7px; border-radius: 50%; background: var(--primary-text);`
- `input[type="checkbox"][data-my-choice-control]:checked::after` → `content: ""; width: 9px; height: 5px; border-left: 2px solid var(--primary-text); border-bottom: 2px solid var(--primary-text); transform: translateY(-1px) rotate(-45deg);`
- `input[type="checkbox"][data-my-choice-control]:indeterminate::after` → `content: ""; width: 9px; height: 2px; border: 0; border-radius: 1px; background: var(--primary-text); transform: none;`
- `.my-choice-copy[data-my-choice-control]` → `flex: 1; min-width: 0; overflow-wrap: anywhere;`
- `.my-choice-label[data-my-choice-control]` → `display: block; color: var(--text); font-size: 14px; font-weight: var(--font-weight-action, 500); line-height: 22px;`
- `.my-choice-description[data-my-choice-control]` → `display: block; margin-top: 3px; color: var(--text-secondary); font-size: 14px; font-weight: var(--font-weight, 400); line-height: 20px;`
- `.my-is-list[data-my-choice-control]` → `display: flex; position: relative; gap: 12px; padding: var(--list-padding-block, 14px) var(--list-padding-inline, 16px); border-radius: 0; --choice-size: 21px;`
- `.my-is-list .my-choice-label[data-my-choice-control]` → `font-size: 15px;`
- `.my-is-list input[type="radio"][data-my-choice-control]:checked::after` → `width: 8px; height: 8px;`
- `.my-is-list input[type="checkbox"][data-my-choice-control]:checked:not( :indeterminate )::after` → `width: 10px; height: 6px;`

</details>
- 视觉证据：packages/core/my-ui.css:712-745（ChoiceGroup）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── ChoiceGroup ───────────────────────────────────────────── */ .my-choice-group[data-my-choice-group]` → `min-width: 0; margin: 0; padding: 0; border: 0;`
- `legend[data-my-choice-group]` → `padding: 0; margin-bottom: 10px; color: var(--text-secondary); font-size: 13px; font-weight: var(--font-weight-action, 500); line-height: 20px;`
- `.my-choice-items[data-my-choice-group]` → `display: flex; flex-direction: column; align-items: stretch; gap: 4px; min-width: 0;`
- `.my-choice-items.my-inline[data-my-choice-group]` → `flex-direction: row; flex-wrap: wrap; align-items: center; gap: 4px 12px;`

</details>

### RadioGroup

- 契约证据：packages/vue/components/RadioGroup.vue:1-26；核心：共享注册/帮助函数，见对应 Vue useNative 调用。
- Props / 变体：`{ modelValue: string label: string options?: Option[] disabled?: boolean inline?: boolean name?: string }`。
- Events：`{ 'update:modelValue': [value: string] }`。
- 默认值：`无显式 withDefaults，见原文件`。
- 核心静态插槽：无静态 c.slot 调用；动态出口见核心实现；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--choice-size`、`--gray`、`--card-background`、`--primary`、`--primary-text`、`--text`、`--font-weight-action`、`--text-secondary`、`--font-weight`、`--list-padding-block`、`--list-padding-inline`、`--hover`、`--press`。
- 视觉证据：packages/core/my-ui.css:582-711（ChoiceControl）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── ChoiceControl ───────────────────────────────────────────── */ .my-choice-control[data-my-choice-control]` → `display: inline-flex; align-items: center; gap: 11px; min-width: 0; min-height: 42px; padding: 7px 8px; border-radius: 10px; cursor: pointer; user-select: none; -webkit-user-select: none; -webkit-tap-highlight-color: transparent; touch-action: manipulation; transition: background-color 0.14s ease;`
- `input[data-my-choice-control]` → `appearance: none; -webkit-appearance: none; display: grid; place-items: center; flex: 0 0 var(--choice-size, 20px); width: var(--choice-size, 20px); height: var(--choice-size, 20px); margin: 0; border: 1.5px solid var(--gray); border-radius: 6px; background: var(--card-background); cursor: inherit; transition: background-color 0.15s ease, border-color 0.15s ease;`
- `input[type="radio"][data-my-choice-control]` → `border-radius: 50%;`
- `input[type="radio"][data-my-choice-control]:checked::after` → `content: ""; width: 7px; height: 7px; border-radius: 50%; background: var(--primary-text);`
- `input[type="checkbox"][data-my-choice-control]:checked::after` → `content: ""; width: 9px; height: 5px; border-left: 2px solid var(--primary-text); border-bottom: 2px solid var(--primary-text); transform: translateY(-1px) rotate(-45deg);`
- `input[type="checkbox"][data-my-choice-control]:indeterminate::after` → `content: ""; width: 9px; height: 2px; border: 0; border-radius: 1px; background: var(--primary-text); transform: none;`
- `.my-choice-copy[data-my-choice-control]` → `flex: 1; min-width: 0; overflow-wrap: anywhere;`
- `.my-choice-label[data-my-choice-control]` → `display: block; color: var(--text); font-size: 14px; font-weight: var(--font-weight-action, 500); line-height: 22px;`
- `.my-choice-description[data-my-choice-control]` → `display: block; margin-top: 3px; color: var(--text-secondary); font-size: 14px; font-weight: var(--font-weight, 400); line-height: 20px;`
- `.my-is-list[data-my-choice-control]` → `display: flex; position: relative; gap: 12px; padding: var(--list-padding-block, 14px) var(--list-padding-inline, 16px); border-radius: 0; --choice-size: 21px;`
- `.my-is-list .my-choice-label[data-my-choice-control]` → `font-size: 15px;`
- `.my-is-list input[type="radio"][data-my-choice-control]:checked::after` → `width: 8px; height: 8px;`
- `.my-is-list input[type="checkbox"][data-my-choice-control]:checked:not( :indeterminate )::after` → `width: 10px; height: 6px;`

</details>
- 视觉证据：packages/core/my-ui.css:712-745（ChoiceGroup）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── ChoiceGroup ───────────────────────────────────────────── */ .my-choice-group[data-my-choice-group]` → `min-width: 0; margin: 0; padding: 0; border: 0;`
- `legend[data-my-choice-group]` → `padding: 0; margin-bottom: 10px; color: var(--text-secondary); font-size: 13px; font-weight: var(--font-weight-action, 500); line-height: 20px;`
- `.my-choice-items[data-my-choice-group]` → `display: flex; flex-direction: column; align-items: stretch; gap: 4px; min-width: 0;`
- `.my-choice-items.my-inline[data-my-choice-group]` → `flex-direction: row; flex-wrap: wrap; align-items: center; gap: 4px 12px;`

</details>

### Segmented

- 契约证据：packages/vue/components/Segmented.vue:1-23；核心：packages/core/my-ui.js:2922。
- Props / 变体：`{ modelValue: string options: Option[] label: string }`。
- Events：`{ 'update:modelValue': [value: string] }`。
- 默认值：`无显式 withDefaults，见原文件`。
- 核心静态插槽：无静态 c.slot 调用；动态出口见核心实现；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--segment-background`、`--fill`、`--border`、`--segment-count`、`--text-secondary`、`--font-weight-action`、`--primary`、`--selected-background`、`--card-background`、`--segment-active-shadow`、`--selected-shadow`、`--segment-shift`。
- 视觉证据：packages/core/my-ui.css:2055-2126（Segmented）。
<details><summary>尺寸、排版、动效规格</summary>

- `.my-segmented[data-my-segmented]` → `background: var(--segment-background, var(--fill)); border: 1px solid var(--border); display: grid; position: relative; isolation: isolate; gap: 0; padding: 4px; border-radius: 14px; overflow: hidden; --segment-shift: 0%; grid-template-columns: repeat(var(--segment-count, 3), minmax(0, 1fr));`
- `.my-segmented button[data-my-segmented]` → `display: flex; align-items: center; justify-content: center; gap: 6px; border: none; background: none; color: var(--text-secondary); padding: 9px 8px; position: relative; z-index: 1; min-height: 40px; border-radius: 10px; font-size: 14px; font-weight: var(--font-weight-action, 500); transform: none; touch-action: manipulation; transition: color 0.2s ease;`
- `.my-segmented[data-my-segmented]::before` → `content: ""; position: absolute; z-index: 0; top: 4px; bottom: 4px; left: 4px; border-radius: 10px; background: var( --segment-active-background, var(--selected-background, var(--card-background)) ); box-shadow: var(--segment-active-shadow, var(--selected-shadow)); transform: translateX(var(--segment-shift)); transition: transform 0.28s cubic-bezier(0.2, 0.78, 0.22, 1); pointer-events: none; width: calc((100% - 8px) / var(--segment-count, 3));`
- `.my-segmented[data-my-segmented]::before` → `transition: none;`

</details>

### Select

- 契约证据：packages/vue/components/Select.vue:1-25；核心：packages/core/my-ui.js:4996。
- Props / 变体：`{ modelValue: string label: string options: Option[] disabled?: boolean }`。
- Events：`{ 'update:modelValue': [value: string] }`。
- 默认值：`无显式 withDefaults，见原文件`。
- 核心静态插槽：hint；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--font-weight-action`、`--text-secondary`、`--input-background`、`--fill`、`--input-border-color`、`--input-height`、`--input-radius`、`--input-padding`、`--input-focus-color`、`--primary`、`--success`、`--input-color`、`--text`、`--hover`。
- 视觉证据：packages/core/my-ui.css:1054-1148（Select）。
<details><summary>尺寸、排版、动效规格</summary>

- `.my-field-label[data-my-select]` → `display: block; font-weight: var(--font-weight-action, 500); color: var(--text-secondary); font-size: 13px; margin-bottom: 8px;`
- `.my-input-box[data-my-select]` → `width: 100%; display: flex; align-items: center; background: var(--input-background, var(--fill)); border: var( --input-border, 1.5px solid var(--input-border-color, transparent) ); color: var(--text-secondary); transition: 0.2s; height: var(--input-height, 44px); border-radius: var(--input-radius, 12px); padding: 0 var(--input-padding, 13px); gap: 9px;`
- `.my-input-box svg[data-my-select]` → `width: 18px; height: 18px;`
- `.my-field-foot[data-my-select]` → `margin-top: 10px; display: flex; justify-content: space-between; gap: 10px; color: var(--text-secondary); font-size: 13px;`
- `.my-field-foot[data-my-select] .my-valid` → `color: var(--success); display: flex; gap: 5px; align-items: center;`
- `.my-field-foot[data-my-select] svg` → `width: 13px; height: 13px;`
- `.my-select-value[data-my-select]` → `font-size: 15px; font-weight: var(--font-weight-action, 500); color: var(--input-color, var(--text)); flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;`
- `.my-select-chevron[data-my-select]` → `width: 18px; height: 18px; flex-shrink: 0; color: var(--text-secondary);`

</details>

### Sheet

- 契约证据：packages/vue/components/Sheet.vue:1-43；核心：packages/core/my-ui.js:3785。
- Props / 变体：`{ modelValue: boolean title: string actions?: Option[] cancelText?: string ∣ false confirmText?: string danger?: boolean swipeable?: boolean closeOnBackdrop?: boolean closeOnEscape?: boolean }`。
- Events：`{ 'update:modelValue': [value: boolean] select: [action: Option] cancel: [] confirm: [] 'after-leave': [] }`。
- 默认值：`{ actions: () => [], cancelText: '取消', swipeable: true, closeOnBackdrop: true, closeOnEscape: true }`。
- 核心静态插槽：无静态 c.slot 调用；动态出口见核心实现；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--primary`、`--font-weight-action`、`--border`、`--danger`、`--press`、`--hover`、`--sheet-margin`、`--overlay-background`、`--overlay-backdrop-filter`、`--card-background`、`--sheet-width`、`--text`、`--sheet-radius`、`--modal-shadow`、`--popup-shadow`、`--list-padding-inline`、`--font-weight-subtitle`、`--gray`、`--list-padding-block`。
- 视觉证据：packages/core/my-ui.css:2680-2741（PopupActions）。
<details><summary>尺寸、排版、动效规格</summary>

- `button[data-my-popup-actions]` → `position: relative; width: 100%; min-width: 0; border: 0; border-radius: 0; background: transparent; color: var(--primary); font: inherit; font-size: 16px; font-weight: var(--font-weight-action, 500); line-height: 24px; padding: 18px 16px calc(24px + env(safe-area-inset-bottom, 0px)); min-height: 66px; touch-action: manipulation; transition: background-color 0.14s;`
- `/* 短线由操作区居中定位，底部延伸留白仍属于按钮点击区。 */ .my-popup-actions.my-paired[data-my-popup-actions]::after` → `content: ""; position: absolute; inset-inline-start: 50%; top: 20px; height: 20px; width: 0; border-inline-start: 1px solid var(--border); pointer-events: none;`
- `button[data-my-popup-actions]:focus-visible::after` → `content: ""; position: absolute; inset: 6px; border: 2px solid var(--primary); border-radius: 12px; pointer-events: none;`

</details>
- 视觉证据：packages/core/my-ui.css:2867-2996（Sheet）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Sheet ───────────────────────────────────────────── */ .my-sheet-overlay[data-my-sheet]` → `position: fixed; inset: 0; width: 100%; padding: var(--sheet-margin, 16px); display: flex; align-items: end; justify-content: center; z-index: 100; isolation: isolate;`
- `.my-sheet-motion-enter-active .my-sheet-scrim[data-my-sheet], .my-sheet-motion-leave-active .my-sheet-scrim[data-my-sheet]` → `transition: opacity 0.25s ease;`
- `.my-sheet-motion-enter-active .my-sheet-dialog[data-my-sheet], .my-sheet-motion-leave-active .my-sheet-dialog[data-my-sheet]` → `transition: opacity 0.25s ease, transform 0.25s cubic-bezier(0.2, 0.7, 0.2, 1);`
- `.my-sheet-dialog[data-my-sheet]` → `position: relative; display: flex; flex-direction: column; min-height: 0; width: min(var(--sheet-width, 400px), 100%); max-height: min(85dvh, calc(100dvh - 2 * var(--sheet-margin, 16px))); background: var(--card-background); color: var(--text); border-radius: var(--sheet-radius, 28px); box-shadow: var(--modal-shadow, var(--popup-shadow)); overflow: hidden;`
- `.my-sheet-overlay[data-swipe-dismissed].my-sheet-motion-leave-active[data-my-sheet], .my-sheet-overlay[data-swipe-dismissed].my-sheet-motion-leave-active .my-sheet-scrim[data-my-sheet], .my-sheet-overlay[data-swipe-dismissed].my-sheet-motion-leave-active .my-sheet-dialog[data-my-sheet]` → `transition: none;`
- `h3[data-my-sheet]` → `margin: 0; flex-shrink: 0; padding: 28px var(--list-padding-inline, 24px) 16px; font-size: 20px; font-weight: var(--font-weight-subtitle, 600); line-height: 1.4; text-align: center; overflow-wrap: anywhere;`
- `.my-sheet-body[data-my-sheet]` → `min-height: 0; overflow-y: auto; overscroll-behavior: contain; scrollbar-width: thin; scrollbar-color: var(--gray) transparent;`
- `.my-sheet-option[data-my-sheet] .my-leading-content` → `width: 20px; height: 20px; border-radius: 0; background: transparent;`
- `.my-sheet-motion-enter-active[data-my-sheet], .my-sheet-motion-leave-active[data-my-sheet], .my-sheet-motion-enter-active .my-sheet-scrim[data-my-sheet], .my-sheet-motion-leave-active .my-sheet-scrim[data-my-sheet], .my-sheet-motion-enter-active .my-sheet-dialog[data-my-sheet], .my-sheet-motion-leave-active .my-sheet-dialog[data-my-sheet]` → `transition: none;`

</details>

### Skeleton

- 契约证据：packages/vue/components/Skeleton.vue:1-22；核心：packages/core/my-ui.js:2210。
- Props / 变体：`{ loading?: boolean rows?: number avatar?: boolean label?: string }`。
- Events：`{}`。
- 默认值：`{ loading: true, rows: 3, label: '内容加载中' }`。
- 核心静态插槽：default；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--fill`。
- 视觉证据：packages/core/my-ui.css:3807-3857（Skeleton）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Skeleton ───────────────────────────────────────────── */ .my-skeleton[data-my-skeleton]` → `min-width: 0;`
- `.my-skeleton-visual[data-my-skeleton]` → `display: flex; gap: 14px; width: 100%; padding: 12px 0; animation: my-pulse-data-my-skeleton 1.5s ease-in-out infinite;`
- `.my-avatar[data-my-skeleton]` → `width: 42px; height: 42px; border-radius: 50%; flex-shrink: 0; background: var(--fill);`
- `.my-skeleton-copy[data-my-skeleton]` → `flex: 1; min-width: 0;`
- `.my-title[data-my-skeleton], .my-line[data-my-skeleton]` → `background: var(--fill); border-radius: 6px;`
- `.my-title[data-my-skeleton]` → `height: 18px; width: 42%; margin-bottom: 18px;`
- `.my-line[data-my-skeleton]` → `height: 13px; margin-top: 12px;`
- `.my-line[data-my-skeleton]:last-child` → `width: 66%;`
- `.my-skeleton-visual[data-my-skeleton]` → `animation: none;`

</details>

### Slider

- 契约证据：packages/vue/components/Slider.vue:1-45；核心：packages/core/my-ui.js:5789。
- Props / 变体：`{ modelValue: T buffer?: number label: string min?: number max?: number step?: number ∣ null marks?: boolean ∣ readonly SliderMark[] valueLabelDisplay?: 'auto' ∣ 'on' ∣ 'off' valueLabelFormat?: (value: number, index: number) => string getAriaValueText?: (value: number, index: number) => string disabled?: boolean unit?: string startLabel?: string endLabel?: string }`。
- Events：`{ 'update:modelValue': [value: T] }`。
- 默认值：`{ min: 0, max: 100, step: 1, marks: false, valueLabelDisplay: 'auto', unit: '%', startLabel: '柔和', endLabel: '鲜明' }`。
- 核心静态插槽：无静态 c.slot 调用；动态出口见核心实现；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--slider-color`、`--progress-color`、`--primary`、`--text-secondary`、`--font-weight-subtitle`、`--slider-thumb-size`、`--slider-track-height`、`--progress-thickness`、`--slider-track-color`、`--progress-track`、`--fill`、`--slider-thumb-border-width`、`--slider-thumb-border-color`、`--slider-thumb-radius`、`--slider-thumb-color`、`--slider-thumb-shadow`、`--slider-position`、`--card-background`。
- 视觉证据：packages/core/my-ui.css:1207-1425（Slider）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Slider ───────────────────────────────────────────── */ /* 九个变量覆盖轨道颜色/粗细和圆块的尺寸、颜色、边框、圆角、阴影。 */ .my-slider[data-my-slider]` → `min-width: 0; color: var(--slider-color, var(--progress-color, var(--primary)));`
- `.my-range-heading[data-my-slider]` → `display: flex; justify-content: space-between; color: var(--text-secondary); margin: 6px 0; font-size: 13px;`
- `.my-slider-control[data-my-slider]` → `position: relative; min-height: max(44px, var(--slider-thumb-size, 20px)); cursor: pointer; touch-action: pan-y;`
- `/* 轨道两端对齐原生圆块中心，填充终点始终跟随圆块。 */ .my-slider .my-slider-track[data-my-slider]` → `position: absolute; top: 50%; right: calc(var(--slider-thumb-size, 20px) / 2); left: calc(var(--slider-thumb-size, 20px) / 2); height: var(--slider-track-height, var(--progress-thickness, 6px)); transform: translateY(-50%); background: var(--slider-track-color, var(--progress-track, var(--fill))); pointer-events: none;`
- `input[type="range"][data-my-slider]` → `position: relative; z-index: 1; display: block; appearance: none; width: 100%; height: max(44px, var(--slider-thumb-size, 20px)); margin: 0; padding: 0; border: 0; outline: 0; color: inherit; background: transparent; cursor: pointer; touch-action: pan-y;`
- `input[data-my-slider]::-webkit-slider-runnable-track` → `height: var(--slider-track-height, var(--progress-thickness, 6px)); background: transparent;`
- `input[data-my-slider]::-moz-range-track` → `height: var(--slider-track-height, var(--progress-thickness, 6px)); background: transparent;`
- `input[data-my-slider]::-webkit-slider-thumb` → `appearance: none; box-sizing: border-box; width: var(--slider-thumb-size, 20px); height: var(--slider-thumb-size, 20px); margin-top: calc( ( var(--slider-track-height, var(--progress-thickness, 6px)) - var(--slider-thumb-size, 20px) ) / 2 ); border: var(--slider-thumb-border-width, 0px) solid var(--slider-thumb-border-color, currentColor); border-radius: var(--slider-thumb-radius, 50%); background: var(--slider-thumb-color, currentColor); box-shadow: var(--slider-thumb-shadow, 0 2px 5px rgb(0 0 0 / 0.22));`
- `input[data-my-slider]::-moz-range-thumb` → `box-sizing: border-box; width: var(--slider-thumb-size, 20px); height: var(--slider-thumb-size, 20px); border: var(--slider-thumb-border-width, 0px) solid var(--slider-thumb-border-color, currentColor); border-radius: var(--slider-thumb-radius, 50%); background: var(--slider-thumb-color, currentColor); box-shadow: var(--slider-thumb-shadow, 0 2px 5px rgb(0 0 0 / 0.22));`
- `.my-range-scale[data-my-slider]` → `display: flex; justify-content: space-between; color: var(--text-secondary); font-size: 11px; margin-top: 2px;`
- `.my-slider-thumb-anchor[data-my-slider]` → `position: absolute; top: 50%; left: calc( var(--slider-thumb-size, 20px) / 2 + (100% - var(--slider-thumb-size, 20px)) * var(--slider-position) ); width: var(--slider-thumb-size, 20px); height: var(--slider-thumb-size, 20px); translate: -50% -50%; pointer-events: none; transition-property: none;`
- `/* 独立光圈保留完整的进出与反向过渡，不依赖原生 range 伪元素的动画支持。 */ .my-slider-halo[data-my-slider]` → `position: absolute; inset: -15px; border-radius: var(--slider-thumb-radius, 50%); background: color-mix( in srgb, var(--slider-thumb-color, currentColor) 14%, transparent ); opacity: 0; scale: 0.4; transition: scale 0.16s ease, opacity 0.16s ease;`
- `.my-slider-marks > span[data-my-slider]` → `position: absolute; width: 2px; height: 2px; border-radius: 50%; background: currentColor; opacity: 0.75; translate: -50% -50%;`
- `.my-slider-mark-labels[data-my-slider]` → `position: relative; height: 20px; margin: 2px calc(var(--slider-thumb-size, 20px) / 2) 0; color: var(--text-secondary); font-size: 12px; line-height: 20px;`

</details>

### Stepper

- 契约证据：packages/vue/components/Stepper.vue:1-27；核心：packages/core/my-ui.js:2941。
- Props / 变体：`{ modelValue: number min?: number max?: number step?: number label?: string }`。
- Events：`{ 'update:modelValue': [value: number] }`。
- 默认值：`{ min: 0, max: 99, step: 1, label: '数量' }`。
- 核心静态插槽：无静态 c.slot 调用；动态出口见核心实现；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--border`、`--card-background`、`--text-secondary`、`--font-weight-action`、`--text`、`--primary`、`--press`、`--hover`。
- 视觉证据：packages/core/my-ui.css:2199-2284（Stepper）。
<details><summary>尺寸、排版、动效规格</summary>

- `.my-stepper[data-my-stepper]` → `height: 44px; display: inline-flex; align-items: stretch; border: 1px solid var(--border); border-radius: 12px; background: var(--card-background); overflow: hidden; transition: border-color 0.18s ease, box-shadow 0.18s ease;`
- `.my-stepper button[data-my-stepper]` → `flex: 0 0 44px; height: 100%; padding: 0 11px; border: 0; background: transparent; color: var(--text-secondary); font-size: 20px; font-weight: var(--font-weight-action, 500); text-align: center; transform: none; touch-action: manipulation; transition: background-color 0.14s ease, color 0.14s ease;`
- `.my-stepper input[data-my-stepper]` → `appearance: textfield; -moz-appearance: textfield; flex: 0 0 48px; width: 48px; min-width: 0; height: 100%; padding: 0 11px; border: 0; outline: 0; background: transparent; color: var(--text); font-size: 14px; font-weight: var(--font-weight-action, 500); text-align: center; font-variant-numeric: tabular-nums; border-inline: 1px solid var(--border); border-radius: 0; box-shadow: none;`
- `.my-stepper input[data-my-stepper]::-webkit-outer-spin-button` → `appearance: none; -webkit-appearance: none; margin: 0;`
- `.my-stepper input[data-my-stepper]::-webkit-inner-spin-button` → `appearance: none; -webkit-appearance: none; margin: 0;`

</details>

### Steps

- 契约证据：packages/vue/components/Steps.vue:1-31；核心：packages/core/my-ui.js:1963。
- Props / 变体：`{ modelValue?: number options?: readonly StepOption[] status?: 'process' ∣ 'error' label?: string vertical?: boolean interactive?: boolean disabled?: boolean }`。
- Events：`{ 'update:modelValue': [value: number] }`。
- 默认值：`{ modelValue: 0, options: () => [], status: 'process', label: '步骤', vertical: false, interactive: false, disabled: false }`。
- 核心静态插槽：无静态 c.slot 调用；动态出口见核心实现；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--step-size`、`--border`、`--primary`、`--text-secondary`、`--card-background`、`--primary-text`、`--text`、`--font-weight-subtitle`、`--danger`。
- 视觉证据：packages/core/my-ui.css:4039-4062（Steps）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Steps ─────────────────────────────────────────────── */ .my-steps[data-my-steps]` → `display: flex; align-items: flex-start; min-width: 0; padding: 0; margin: 0; list-style: none;`
- `.my-step[data-my-steps]` → `position: relative; flex: 1; min-width: 0;`
- `.my-step[data-my-steps]:not(:last-child)::after` → `content: ""; position: absolute; top: calc(var(--step-size, 32px) / 2 + 3px); left: calc(50% + var(--step-size, 32px) / 2 + 6px); right: calc(-50% + var(--step-size, 32px) / 2 + 6px); height: 1px; background: var(--border); pointer-events: none;`
- `.my-step-body[data-my-steps]` → `display: flex; flex-direction: column; align-items: center; gap: 10px; width: 100%; min-width: 0; padding: 3px 8px; border: 0; border-radius: 10px; background: transparent; color: var(--text-secondary); font: inherit; text-align: center;`
- `.my-step-mark[data-my-steps]` → `display: flex; align-items: center; justify-content: center; flex: 0 0 auto; width: var(--step-size, 32px); height: var(--step-size, 32px); border: 1px solid var(--border); border-radius: 50%; background: var(--card-background); font-size: 13px; font-variant-numeric: tabular-nums;`
- `.my-step-mark svg[data-my-steps]` → `width: 17px; height: 17px;`
- `.my-step-copy[data-my-steps]` → `display: block; min-width: 0;`
- `.my-step-label[data-my-steps]` → `display: block; font-size: 13px; line-height: 1.6; overflow-wrap: anywhere;`
- `.my-step-description[data-my-steps]` → `display: block; margin-top: 3px; font-size: 11px; line-height: 1.6; color: var(--text-secondary); overflow-wrap: anywhere;`
- `.my-steps.my-vertical[data-my-steps]` → `flex-direction: column; gap: 22px;`
- `.my-steps.my-vertical .my-step[data-my-steps]` → `flex: none; width: 100%;`
- `.my-steps.my-vertical .my-step-body[data-my-steps]` → `flex-direction: row; align-items: flex-start; gap: 12px; padding: 3px; text-align: start;`
- `.my-steps.my-vertical .my-step[data-my-steps]:not(:last-child)::after` → `top: calc(var(--step-size, 32px) + 10px); bottom: -16px; left: calc(var(--step-size, 32px) / 2 + 3px); right: auto; width: 1px; height: auto;`

</details>

### Switch

- 契约证据：packages/vue/components/Switch.vue:1-23；核心：packages/core/my-ui.js:1358。
- Props / 变体：`{ modelValue: boolean label: string disabled?: boolean }`。
- Events：`{ 'update:modelValue': [value: boolean] }`。
- 默认值：`无显式 withDefaults，见原文件`。
- 核心静态插槽：无静态 c.slot 调用；动态出口见核心实现；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--gray`、`--switch-thumb-background`、`--primary`、`--primary-text`。
- 视觉证据：packages/core/my-ui.css:544-581（Switch）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Switch ───────────────────────────────────────────── */ .my-switch[data-my-switch]` → `position: relative; width: 47px; height: 28px; appearance: none; border: 0; background: var(--gray); border-radius: 99px; cursor: pointer; transition: background 0.23s; flex-shrink: 0; touch-action: manipulation;`
- `.my-switch[data-my-switch]::after` → `content: ""; position: absolute; width: 22px; height: 22px; top: 3px; left: 3px; background: var(--switch-thumb-background, #fff); border-radius: 50%; box-shadow: 0 2px 5px rgb(0 0 0 / 0.12); transition: transform 0.23s, background-color 0.15s;`

</details>

### Tabbar

- 契约证据：packages/vue/components/Tabbar.vue:1-23；核心：packages/core/my-ui.js:2932。
- Props / 变体：`{ modelValue: string options: Option[] label?: string }`。
- Events：`{ 'update:modelValue': [value: string] }`。
- 默认值：`{ label: '主导航' }`。
- 核心静态插槽：无静态 c.slot 调用；动态出口见核心实现；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--fill`、`--border`、`--text-secondary`、`--primary`、`--font-weight-action`、`--tabbar-height`、`--tabbar-safe-bottom`、`--card-background`。
- 视觉证据：packages/core/my-ui.css:2127-2183（Navigation）。
<details><summary>尺寸、排版、动效规格</summary>

- `.my-navigation:is([data-my-navigation], [data-my-tabbar])` → `background: var(--fill); border: 1px solid var(--border); display: flex; justify-content: space-between; gap: 4px; height: 56px; min-height: 56px; padding: 3px 5px; border-radius: 15px; align-items: stretch;`
- `.my-navigation button:is([data-my-navigation], [data-my-tabbar])` → `min-width: 0; flex: 1; border: none; background: transparent; display: flex; align-items: center; justify-content: center; flex-direction: column; color: var(--text-secondary); opacity: 1; transform: none; touch-action: manipulation; transition: opacity 0.2s ease, color 0.15s ease; height: 100%; min-height: 0; padding: 3px 4px; gap: 2px; border-radius: 10px; font-size: 12px; line-height: 1.15;`
- `.my-navigation button svg:is([data-my-navigation], [data-my-tabbar])` → `height: 24px; width: 24px;`

</details>
- 视觉证据：packages/core/my-ui.css:2184-2198（Tabbar）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Tabbar：普通布局中的底栏，页面自行决定是否固定 ────────── */ .my-tabbar[data-my-tabbar]` → `flex: 0 0 auto; height: calc(var(--tabbar-height, 64px) + var(--tabbar-safe-bottom, env(safe-area-inset-bottom, 0px))); min-height: calc(var(--tabbar-height, 64px) + var(--tabbar-safe-bottom, env(safe-area-inset-bottom, 0px))); padding: 4px max(8px, env(safe-area-inset-right, 0px)) calc(4px + var(--tabbar-safe-bottom, env(safe-area-inset-bottom, 0px))) max(8px, env(safe-area-inset-left, 0px)); border: 0; border-top: 1px solid var(--border); border-radius: 0; background: var(--card-background);`
- `.my-tabbar button[data-my-tabbar]` → `height: auto; min-height: 44px;`

</details>

### Tabs

- 契约证据：packages/vue/components/Tabs.vue:1-25；核心：packages/core/my-ui.js:7117。
- Props / 变体：`{ modelValue: string options: Option[] label: string swipeable?: boolean }`。
- Events：`{ 'update:modelValue': [value: string] }`。
- 默认值：`{ swipeable: true }`。
- 核心静态插槽：default；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--border`、`--text-secondary`、`--primary`、`--hover`、`--press`。
- 视觉证据：packages/core/my-ui.css:1957-2054（Tabs）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Tabs ───────────────────────────────────────────── */ .my-tabs[data-my-tabs]` → `min-width: 0;`
- `.my-tab-strip[data-my-tabs]` → `position: relative; display: flex; gap: 6px; border-bottom: 1px solid var(--border); overflow-x: auto; scrollbar-width: none;`
- `.my-tab-strip button[data-my-tabs]` → `position: relative; flex: 0 0 auto; min-height: 44px; padding: 0 16px; border: 0; border-radius: 9px 9px 0 0; background: transparent; color: var(--text-secondary); font-size: 14px; white-space: nowrap; touch-action: manipulation; -webkit-tap-highlight-color: transparent;`
- `.my-tab-indicator[data-my-tabs]` → `position: absolute; height: 3px; left: 0; bottom: 0; border-radius: 4px; background: transparent; pointer-events: none;`
- `.my-tab-indicator[data-my-tabs]::after` → `content: ""; position: absolute; inset: 0 16px; border-radius: inherit; background: var(--primary);`
- `.my-tab-panel.my-is-preview[data-my-tabs]` → `position: absolute; top: 0; width: 100%;`
- `.my-no-tabs[data-my-tabs]` → `font-size: 13px; color: var(--text-secondary); text-align: center; padding: 20px 0;`

</details>

### Tag

- 契约证据：packages/vue/components/Tag.vue:1-25；核心：packages/core/my-ui.js:1317。
- Props / 变体：`{ modelValue?: boolean tone?: 'blue' ∣ 'green' ∣ 'orange' ∣ 'red' ∣ 'gray' disabled?: boolean }`。
- Events：`{ 'update:modelValue': [value: boolean] click: [event: MouseEvent] }`。
- 默认值：`{ tone: 'blue', modelValue: undefined }`。
- 核心静态插槽：default；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--primary`、`--tag-color`、`--card-background`、`--font-weight-action`、`--success`、`--warning`、`--danger`、`--text-secondary`、`--border`、`--primary-text`、`--press`、`--hover`。
- 视觉证据：packages/core/my-ui.css:443-534（Tag）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Tag ───────────────────────────────────────────── */ /* 外层始终保留完整点击区域，缩放只影响不接收指针的内层。 */ .my-tag[data-my-tag]` → `--tag-color: var(--primary); display: inline-flex; align-items: stretch; padding: 0; border: 0; background: transparent; border-radius: 999px; font: inherit; vertical-align: middle;`
- `.my-tag-content[data-my-tag]` → `box-sizing: border-box; display: inline-flex; align-items: center; justify-content: center; gap: 6px; min-height: 28px; padding: 0 12px; border: 1px solid color-mix(in srgb, var(--tag-color) 18%, var(--card-background)); border-radius: inherit; color: var(--tag-color); background: color-mix(in srgb, var(--tag-color) 10%, var(--card-background)); font-size: 13px; font-weight: var(--font-weight-action, 500); line-height: 20px; white-space: nowrap; pointer-events: none; transition: transform 0.16s ease, background-color 0.16s ease, color 0.16s ease;`
- `.my-tag-content[data-my-tag] svg` → `width: 16px; height: 16px;`
- `.my-is-selectable[data-my-tag]` → `border-radius: 11px; cursor: pointer; touch-action: manipulation; user-select: none;`
- `.my-is-selectable .my-tag-content[data-my-tag]` → `min-height: 32px; border-color: var(--border); background: var(--card-background); color: var(--text-secondary);`

</details>

### TagGroup

- 契约证据：packages/vue/components/TagGroup.vue:1-25；核心：packages/core/my-ui.js:2618。
- Props / 变体：`{ modelValue: T options: Option[] label: string disabled?: boolean }`。
- Events：`{ 'update:modelValue': [value: T] }`。
- 默认值：`无显式 withDefaults，见原文件`。
- 核心静态插槽：无静态 c.slot 调用；动态出口见核心实现；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：宿主/子组件继承，组件自身无单独 CSS 变量。
- 视觉证据：packages/core/my-ui.css:535-543（TagGroup）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── TagGroup ───────────────────────────────────────────── */ .my-tag-group[data-my-tag-group]` → `display: flex; flex-wrap: wrap; gap: 9px; min-width: 0;`

</details>

### Textarea

- 契约证据：packages/vue/components/Textarea.vue:1-39；核心：packages/core/my-ui.js:2439。
- Props / 变体：`{ modelValue: string label: string id?: string placeholder?: string rows?: number maxlength?: number disabled?: boolean readonly?: boolean required?: boolean error?: string hint?: string }`。
- Events：`{ 'update:modelValue': [value: string] }`。
- 默认值：`{ placeholder: '', rows: 3 }`。
- 核心静态插槽：default；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--input-height`、`--input-padding`、`--input-border-color`、`--input-radius`、`--input-background`、`--fill`、`--input-color`、`--text`、`--text-secondary`、`--input-focus-color`、`--primary`、`--danger`。
- 视觉证据：packages/core/my-ui.css:1008-1053（Textarea）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Textarea ───────────────────────────────────────────── */ .my-textarea[data-my-textarea]` → `box-sizing: border-box; display: block; width: 100%; min-height: var(--input-height, 76px); height: var(--input-height, auto); padding: var(--input-padding, 12px 13px); border: var( --input-border, 1.5px solid var(--input-border-color, transparent) ); border-radius: var(--input-radius, 12px); outline: 0; background: var(--input-background, var(--fill)); color: var(--input-color, var(--text)); line-height: 1.65; resize: vertical; transition: background-color 0.2s, border-color 0.2s;`

</details>

### TimePicker

- 契约证据：packages/vue/components/TimePicker.vue:1-32；核心：共享注册/帮助函数，见对应 Vue useNative 调用。
- Props / 变体：`{ modelValue?: string ∣ null min?: string max?: string minuteStep?: number secondStep?: number showSeconds?: boolean label?: string disabled?: boolean }`。
- Events：`{ 'update:modelValue': [value: string] }`。
- 默认值：`{ label: '选择时间', minuteStep: 1, secondStep: 1, showSeconds: false, disabled: false }`。
- 核心静态插槽：无静态 c.slot 调用；动态出口见核心实现；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--calendar-width`、`--text`、`--font-weight-subtitle`、`--text-secondary`、`--primary`、`--calendar-day-size`、`--primary-text`、`--hover`、`--press`。
- 视觉证据：packages/core/my-ui.css:1510-1595（DatePicker / TimePicker / Calendar）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── DatePicker / TimePicker / Calendar ───────────────────────── */ /* 日期和时间滚轮沿用 Picker 变量，独立日历用紧凑的七列网格。 */ .my-date-picker[data-my-date-picker], .my-time-picker[data-my-time-picker]` → `min-width: 0;`
- `.my-calendar[data-my-calendar]` → `width: 100%; max-width: var(--calendar-width, 360px); min-width: 0; color: var(--text); font-size: 14px; font-variant-numeric: tabular-nums;`
- `.my-calendar-header[data-my-calendar]` → `display: flex; align-items: center; justify-content: space-between; gap: 8px; margin-bottom: 18px;`
- `.my-calendar-heading[data-my-calendar]` → `font-size: 17px; font-weight: var(--font-weight-subtitle, 600); white-space: nowrap;`
- `.my-calendar-nav[data-my-calendar]` → `display: flex; align-items: center; gap: 4px;`
- `.my-calendar-nav-button[data-my-calendar], .my-calendar-today[data-my-calendar]` → `display: inline-flex; align-items: center; justify-content: center; flex: 0 0 auto; height: 32px; padding: 0; border: 0; border-radius: 8px; background: transparent; color: var(--text-secondary); transition: background 120ms, color 120ms;`
- `.my-calendar-nav-button[data-my-calendar]` → `width: 32px;`
- `.my-calendar-nav-button svg[data-my-calendar]` → `width: 18px; height: 18px;`
- `.my-calendar-today[data-my-calendar]` → `padding: 0 8px; font-size: 12px;`
- `.my-calendar-weekdays[data-my-calendar]` → `margin-bottom: 6px; color: var(--text-secondary); font-size: 12px; text-align: center; line-height: 28px;`
- `.my-calendar-week[data-my-calendar]` → `padding: 3px 0;`
- `.my-calendar-cell[data-my-calendar]` → `position: relative; display: flex; justify-content: center; align-items: center; min-width: 0;`
- `.my-calendar-day[data-my-calendar]` → `position: relative; display: flex; align-items: center; justify-content: center; width: min(var(--calendar-day-size, 36px), 100%); height: var(--calendar-day-size, 36px); padding: 0; border: 0; border-radius: 50%; background: transparent; color: var(--text); font-size: 14px; line-height: 1; transition: background 120ms, color 120ms;`
- `.my-calendar-day[aria-current="date"][data-my-calendar]::after` → `content: ""; position: absolute; bottom: 3px; width: 3px; height: 3px; border-radius: 50%; background: currentColor;`
- `.my-calendar-status[data-my-calendar]` → `margin-top: 12px; min-height: 20px; color: var(--text-secondary); font-size: 12px; line-height: 1.65; overflow-wrap: anywhere;`
- `.my-calendar button[data-my-calendar]` → `transition: none;`

</details>

### Toast

- 契约证据：packages/vue/components/Toast.vue:1-16；核心：packages/core/my-ui.js:7503。
- Props / 变体：`{ duration?: number }`。
- Events：`{}`。
- 默认值：`{ duration: 2600 }`。
- 核心静态插槽：无静态 c.slot 调用；动态出口见核心实现；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--text`、`--background`、`--popup-shadow`。
- 视觉证据：packages/core/my-ui.css:4155-4193（Toast）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Toast ───────────────────────────────────────────── */ .my-toast[data-my-toast]` → `position: fixed; bottom: 32px; left: 50%; transform: translate(-50%, 24px); opacity: 0; visibility: hidden; display: flex; align-items: center; gap: 10px; max-width: calc(100% - 32px); background: var(--text); backdrop-filter: blur(10px); color: var(--background); box-shadow: var(--popup-shadow); border-radius: 16px; padding: 15px 20px; font-size: 14px; z-index: 120; transition: opacity 0.22s, transform 0.22s, visibility 0.22s; white-space: normal; overflow-wrap: anywhere;`
- `.my-toast svg[data-my-toast]` → `width: 18px; height: 18px; color: currentColor;`

</details>

### Tooltip

- 契约证据：packages/vue/components/Tooltip.vue:1-35；核心：packages/core/my-ui.js:5413。
- Props / 变体：`{ content?: string placement?: FloatingPlacement arrow?: boolean delay?: number hideDelay?: number longPressDelay?: number copyable?: boolean disabled?: boolean modelValue?: boolean }`。
- Events：`{ 'update:modelValue': [value: boolean] }`。
- 默认值：`{ content: '', placement: 'top', arrow: true, delay: 200, hideDelay: 100, longPressDelay: 500, copyable: false, modelValue: undefined }`。
- 核心静态插槽：default、content；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--tooltip-max-width`、`--_tooltip-arrow-mask`、`--_tooltip-arrow-position`、`--_tooltip-arrow-size`、`--floating-anchor-x`、`--floating-anchor-y`、`--tooltip-color`、`--font-weight`。
- 视觉证据：packages/core/my-ui.css:3174-3316（TooltipPopup）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── TooltipPopup ───────────────────────────────────────────── */ /* 留在组件内部，普通说明与滑块数值提示复用同一外观和定位。 */ .my-floating-panel.my-tooltip-panel` → `--floating-width: max-content; --floating-gap: 0px; display: flex; flex-direction: column; width: max-content; max-width: min(calc(var(--tooltip-max-width, 280px) + 16px), 100%); padding: 8px; overflow: visible; border-radius: 4px; background: transparent; box-shadow: none; pointer-events: none; -webkit-user-select: none; user-select: none;`
- `/* Flutter Tooltip 的紧凑圆角、90% 不透明背景和反色文字，不使用卡片阴影。 */ .my-tooltip-content[data-my-tooltip-popup]` → `position: relative; box-sizing: border-box; min-height: 24px; max-width: var(--tooltip-max-width, 280px); padding: 4px 8px; overflow: hidden; border-radius: inherit; color: var(--tooltip-color, light-dark(#fff, #000)); font-size: 12px; font-weight: var(--font-weight, 400); line-height: 16px; overflow-wrap: anywhere;`
- `.my-tooltip-arrow[data-my-tooltip-popup]` → `position: absolute; width: 12px; height: 6px; pointer-events: none;`
- `.my-floating-position[data-side="left"] .my-tooltip-panel .my-tooltip-arrow` → `right: 2px; top: clamp(18px, var(--floating-anchor-y, 50%), calc(100% - 18px)); width: 6px; height: 12px; translate: 0 -50%; clip-path: polygon(0 0, 100% 50%, 0 100%);`
- `.my-floating-position[data-side="right"] .my-tooltip-panel .my-tooltip-arrow` → `left: 2px; top: clamp(18px, var(--floating-anchor-y, 50%), calc(100% - 18px)); width: 6px; height: 12px; translate: 0 -50%; clip-path: polygon(100% 0, 100% 100%, 0 50%);`
- `.my-tooltip-content[data-my-tooltip-popup]` → `min-height: 32px; padding: 6px 16px; font-size: 14px; line-height: 20px;`

</details>
- 视觉证据：packages/core/my-ui.css:3317-3329（Tooltip）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Tooltip ───────────────────────────────────────────── */ .my-tooltip-trigger[data-my-tooltip]` → `display: inline-flex; align-items: center; vertical-align: middle; min-width: 0;`

</details>

### Upload

- 契约证据：packages/vue/components/Upload.vue:1-49；核心：packages/core/my-ui.js:2020。
- Props / 变体：`{ modelValue?: readonly UploadFile[] label?: string accept?: string multiple?: boolean maxCount?: number maxSize?: number drag?: boolean disabled?: boolean autoUpload?: boolean request?: UploadRequest hint?: string }`。
- Events：`{ 'update:modelValue': [files: UploadFile[]] reject: [files: UploadRejection[]] success: [file: UploadFile] error: [file: UploadFile] cancel: [file: UploadFile] remove: [file: UploadFile] }`。
- 默认值：`{ modelValue: () => [], label: '上传文件', accept: '', multiple: false, drag: false, disabled: false, autoUpload: true, hint: '' }`。
- 核心静态插槽：无静态 c.slot 调用；动态出口见核心实现；Vue 属性与插槽统一由 packages/vue/adapter.ts:68-106、136-160 同步。
- Token：`--text-secondary`、`--border`、`--upload-radius`、`--fill`、`--text`、`--primary`、`--card-background`、`--danger`、`--success`、`--press`、`--hover`、`--notice-color`。
- 视觉证据：packages/core/my-ui.css:4063-4102（Upload）。
<details><summary>尺寸、排版、动效规格</summary>

- `/* ── Upload ────────────────────────────────────────────── */ .my-upload[data-my-upload]` → `min-width: 0;`
- `.my-upload-controls[data-my-upload]` → `display: flex; flex-wrap: wrap; align-items: center; gap: 12px;`
- `.my-upload-hint[data-my-upload], .my-upload-drop-hint[data-my-upload]` → `color: var(--text-secondary); font-size: 12px; line-height: 1.7;`
- `.my-upload-drop[data-my-upload]` → `display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 10px; width: 100%; min-height: 164px; padding: 24px 18px; border: 1px dashed var(--border); border-radius: var(--upload-radius, 14px); background: var(--fill); color: var(--text); transition: border-color 150ms, background 150ms;`
- `.my-upload-drop > svg[data-my-upload]` → `width: 28px; height: 28px; color: var(--primary);`
- `.my-upload-drop > strong[data-my-upload]` → `font-size: 14px;`
- `.my-upload-list[data-my-upload]` → `display: grid; gap: 10px; padding: 0; margin: 16px 0 0; list-style: none;`
- `.my-upload-file[data-my-upload]` → `display: flex; align-items: center; gap: 12px; min-width: 0; padding: 12px; border: 1px solid var(--border); border-radius: 12px;`
- `.my-upload-thumb[data-my-upload]` → `display: flex; align-items: center; justify-content: center; flex: 0 0 40px; height: 40px; overflow: hidden; border-radius: 8px; background: var(--fill); color: var(--text-secondary);`
- `.my-upload-thumb img[data-my-upload]` → `width: 100%; height: 100%; object-fit: cover;`
- `.my-upload-thumb svg[data-my-upload]` → `width: 22px; height: 22px;`
- `.my-upload-file-body[data-my-upload]` → `flex: 1; min-width: 0;`
- `.my-upload-name[data-my-upload]` → `overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: 13px; line-height: 1.6;`
- `.my-upload-detail[data-my-upload]` → `display: flex; flex-wrap: wrap; gap: 2px 8px; color: var(--text-secondary); font-size: 11px; line-height: 1.6; overflow-wrap: anywhere;`
- `.my-upload-file .my-progress-track[data-my-progress-track]` → `height: 3px;`
- `.my-upload-actions[data-my-upload]` → `display: flex; align-items: center; gap: 4px; flex: 0 0 auto;`
- `.my-upload-action[data-my-upload]` → `min-width: 28px; height: 30px; padding: 0 5px; border-radius: 8px; color: var(--primary); font-size: 12px;`
- `.my-upload-action[data-upload-action="remove"][data-my-upload]` → `width: 30px; padding: 0; color: var(--text-secondary);`
- `.my-upload-action svg[data-my-upload]` → `width: 16px; height: 16px;`
- `.my-upload-message[data-my-upload]` → `margin-top: 10px; color: var(--text-secondary); font-size: 12px; line-height: 1.7; overflow-wrap: anywhere;`
- `.my-notice[data-my-notice], .my-upload-drop[data-my-upload]` → `transition: none;`

</details>


## 示例、测试与历史参考的验收边界

- example/src/commons/theme/index.js:1-3 明确配色预设属于示例；其light/dark默认层与核心一致（20-66），clear/warm等预设不混进组件默认值。
- example/src/pages/home/primitives/index.vue:59-110 组合Button/Divider/Tooltip；reference/blue_mobile_components_v10.html:108-125、168-171、360-362 为历史尺寸/颜色，当前CSS已演进（如Card .96与历史.98），以当前核心为准。
- tests/feedback-primitives.browser.html:12-14 规定Progress和Divider的CSS变量使用场景；tests/button-press.browser.html、press-feedback.browser.html、native-core.browser.html包含按钮时序、保留节点、主题/布局；本轮只读参照，不修改或启动其服务。
- tests/theme.test.mjs、theme-state.test.ts、theme-startup.test.mjs、theme-sync.browser.html是示例主题/持久化校验；Flutter主题内核本轮不承担localStorage/Pinia/Tauri桥接。
- 后续值规则验收优先tests/date-time.test.mjs、picker-value.test.mjs、slider-value.test.mjs、upload-structure.test.mjs；浏览器/设备专用验收不能由Flutter单测替代。

## 条件样式索引（保留条件，避免把媒体规则当无条件覆盖）

上文同选择器可能重复列出；以下条件及行号决定实际生效范围。

| 条件 | CSS证据 | 作用域 |
| --- | --- | --- |
| `@media (prefers-reduced-motion: reduce)` | packages/core/my-ui.css:139-150 | `html`；`*, *::before, *::after` |
| `@media (hover: hover) and (pointer: fine)` | packages/core/my-ui.css:397-429 | `.my-button.my-primary[data-my-button]:not(.my-is-loading):not( :disabled ):not([data-my-press-input]):hover:not(:active):not([data-my-pressed])`；`.my-button.my-outline[data-my-button]:not(.my-is-loading):not( :disabled ):not([data-my-press-input]):hover:not(:active):not([data-my-pressed])`；`.my-round-arrow[data-my-button]:not(.my-is-loading):not(:disabled):not([data-my-press-input]):hover:not(:active):not([data-my-pressed])`；`.my-icon-button[data-my-button]:not(.my-bare-icon):not(.my-is-loading):not( :disabled ):not([data-my-press-input]):hover:not(:active):not([data-my-pressed])`；`.my-button.my-text-only[data-my-button]:not(.my-is-loading):not( :disabled ):not([data-my-press-input]):hover:not(:active):not([data-my-pressed])`；`.my-icon-button.my-bare-icon[data-my-button]:not(.my-is-loading):not( :disabled ):not([data-my-press-input]):hover:not(:active):not([data-my-pressed])`；`.my-underlink[data-my-button]:not(.my-is-loading):not(:disabled):not([data-my-press-input]):hover:not(:active):not([data-my-pressed])` |
| `@media (max-width: 1100px)` | packages/core/my-ui.css:430-434 | `.my-button[data-my-button]` |
| `@media (max-width: 400px)` | packages/core/my-ui.css:435-441 | `.my-button[data-my-button]` |
| `@media (hover: hover) and (pointer: fine)` | packages/core/my-ui.css:524-533 | `.my-is-selectable:not(.my-is-disabled):hover:not(:active) .my-tag-content[data-my-tag]`；`.my-is-selected:not(.my-is-disabled):hover:not(:active) .my-tag-content[data-my-tag]` |
| `@media (hover: hover) and (pointer: fine)` | packages/core/my-ui.css:701-705 | `.my-choice-control[data-my-choice-control]:not(:has(input:disabled)):hover` |
| `@media (hover: none) and (pointer: coarse)` | packages/core/my-ui.css:706-710 | `.my-choice-control[data-my-choice-control]:not(:has(input:disabled)):active` |
| `@media (max-width: 600px)` | packages/core/my-ui.css:869-874 | `.my-form-field.my-horizontal[data-my-form-field]` |
| `@media (hover: hover) and (pointer: fine)` | packages/core/my-ui.css:1001-1006 | `.my-input-action:not(:disabled):hover:not(:active) .my-input-action-visual[data-my-input]` |
| `@media (hover: hover) and (pointer: fine)` | packages/core/my-ui.css:1143-1147 | `.my-select-trigger[data-my-select]:not(:disabled):hover` |
| `@media (hover: hover) and (pointer: fine)` | packages/core/my-ui.css:1362-1370 | `.my-slider-thumb-anchor.my-is-hovered .my-slider-halo[data-my-slider]` |
| `@media (prefers-reduced-motion: reduce)` | packages/core/my-ui.css:1420-1424 | `.my-slider-halo[data-my-slider]` |
| `@media (hover: hover)` | packages/core/my-ui.css:1584-1588 | `.my-calendar-nav-button[data-my-calendar]:not(:disabled):hover, .my-calendar-today[data-my-calendar]:not(:disabled):hover, .my-calendar-day[data-my-calendar]:not(.my-is-disabled):not(.my-selected):hover` |
| `@media (prefers-reduced-motion: reduce)` | packages/core/my-ui.css:1592-1594 | `.my-calendar button[data-my-calendar]` |
| `@media (prefers-reduced-motion: reduce)` | packages/core/my-ui.css:1641-1650 | `.my-progress-fill[data-my-progress-track], .my-progress-buffer[data-my-progress-track]`；`.my-is-indeterminate .my-progress-fill[data-my-progress-track]` |
| `@media (prefers-reduced-motion: reduce)` | packages/core/my-ui.css:1752-1760 | `.my-ring-fill[data-my-progress], .my-ring-buffer[data-my-progress]`；`.my-circle.my-indeterminate .my-ring-value[data-my-progress]` |
| `@media (hover: hover) and (pointer: fine)` | packages/core/my-ui.css:1934-1938 | `.my-list-row[data-my-list-row]:not(.my-is-disabled):not([data-my-press-input]):hover:not(:active)` |
| `@media (hover: hover) and (pointer: fine)` | packages/core/my-ui.css:2044-2048 | `.my-tab-strip button[data-my-tabs]:not(:disabled):hover` |
| `@media (hover: none) and (pointer: coarse)` | packages/core/my-ui.css:2049-2053 | `.my-tab-strip button[data-my-tabs]:not(:disabled):active` |
| `@media (prefers-reduced-motion: reduce)` | packages/core/my-ui.css:2121-2125 | `.my-segmented[data-my-segmented]::before` |
| `@media (hover: hover) and (pointer: fine)` | packages/core/my-ui.css:2278-2283 | `.my-stepper button[data-my-stepper]:not(:disabled):hover:not(:active)` |
| `@media (hover: hover) and (pointer: fine)` | packages/core/my-ui.css:2371-2375 | `.my-collapse-trigger[data-my-collapse-item]:not(:disabled):hover` |
| `@media (hover: none) and (pointer: coarse)` | packages/core/my-ui.css:2376-2380 | `.my-collapse-trigger[data-my-collapse-item]:not(:disabled):active` |
| `@media (prefers-reduced-motion: reduce)` | packages/core/my-ui.css:2381-2387 | `.my-collapse-region[data-my-collapse-item], .my-collapse-region.my-open[data-my-collapse-item], .my-collapse-arrow[data-my-collapse-item]` |
| `@media (prefers-reduced-motion: reduce)` | packages/core/my-ui.css:2510-2532 | `.my-floating-panel[data-my-floating]`；`.my-floating-position .my-floating-motion-enter-active[data-my-floating], .my-floating-position .my-floating-motion-leave-active[data-my-floating]`；`.my-floating-panel[data-cascade].my-floating-motion-enter-active[data-my-floating], .my-floating-panel[data-cascade].my-floating-motion-leave-active[data-my-floating]`；`.my-floating-position[data-motion] .my-floating-motion-enter-from[data-my-floating], .my-floating-position[data-motion] .my-floating-motion-leave-to[data-my-floating]` |
| `@media (max-width: 760px)` | packages/core/my-ui.css:2600-2607 | `.my-menu-chevron-desktop[data-my-menu-panel]`；`.my-menu-chevron-mobile[data-my-menu-panel]` |
| `@media (prefers-reduced-motion: reduce)` | packages/core/my-ui.css:2661-2666 | `.my-menu-return-enter-active[data-my-menu-panel], .my-menu-return-leave-active[data-my-menu-panel]` |
| `@media (hover: hover) and (pointer: fine)` | packages/core/my-ui.css:2736-2740 | `button[data-my-popup-actions]:hover:not(:active)` |
| `@media (prefers-reduced-motion: reduce)` | packages/core/my-ui.css:2850-2865 | `.my-dialog-motion-enter-active[data-my-dialog], .my-dialog-motion-leave-active[data-my-dialog], .my-dialog-motion-enter-active .my-dialog[data-my-dialog], .my-dialog-motion-leave-active .my-dialog[data-my-dialog]`；`.my-dialog-motion-enter-from[data-my-dialog], .my-dialog-motion-leave-to[data-my-dialog]`；`.my-overlay.my-dialog-motion-enter-from .my-dialog[data-my-dialog], .my-overlay.my-dialog-motion-leave-to .my-dialog[data-my-dialog]` |
| `@media (prefers-reduced-motion: reduce)` | packages/core/my-ui.css:2976-2995 | `.my-sheet-motion-enter-active[data-my-sheet], .my-sheet-motion-leave-active[data-my-sheet], .my-sheet-motion-enter-active .my-sheet-scrim[data-my-sheet], .my-sheet-motion-leave-active .my-sheet-scrim[data-my-sheet], .my-sheet-motion-enter-active .my-sheet-dialog[data-my-sheet], .my-sheet-motion-leave-active .my-sheet-dialog[data-my-sheet]`；`.my-sheet-motion-enter-from .my-sheet-scrim[data-my-sheet], .my-sheet-motion-leave-to .my-sheet-scrim[data-my-sheet], .my-sheet-motion-enter-from .my-sheet-dialog[data-my-sheet], .my-sheet-motion-leave-to .my-sheet-dialog[data-my-sheet]`；`.my-sheet-motion-enter-from .my-sheet-dialog[data-my-sheet], .my-sheet-motion-leave-to .my-sheet-dialog[data-my-sheet]` |
| `@media (hover: hover) and (pointer: fine)` | packages/core/my-ui.css:3148-3152 | `.my-drawer-close[data-my-drawer]:hover:not(:active)` |
| `@media (prefers-reduced-motion: reduce)` | packages/core/my-ui.css:3153-3172 | `.my-drawer-motion-enter-active[data-my-drawer], .my-drawer-motion-leave-active[data-my-drawer], .my-drawer-motion-enter-active .my-drawer-scrim[data-my-drawer], .my-drawer-motion-leave-active .my-drawer-scrim[data-my-drawer], .my-drawer-motion-enter-active .my-drawer[data-my-drawer], .my-drawer-motion-leave-active .my-drawer[data-my-drawer]`；`.my-drawer-motion-enter-from .my-drawer-scrim[data-my-drawer], .my-drawer-motion-leave-to .my-drawer-scrim[data-my-drawer], .my-drawer-motion-enter-from .my-drawer[data-my-drawer], .my-drawer-motion-leave-to .my-drawer[data-my-drawer]`；`.my-drawer-overlay.my-drawer-motion-enter-from .my-drawer[data-my-drawer], .my-drawer-overlay.my-drawer-motion-leave-to .my-drawer[data-my-drawer]` |
| `@media (pointer: coarse)` | packages/core/my-ui.css:3308-3315 | `.my-tooltip-content[data-my-tooltip-popup]` |
| `@media (hover: hover)` | packages/core/my-ui.css:3585-3587 | `.my-image-preview-button[data-my-image-preview]:not(:disabled):hover` |
| `@media (max-width: 600px)` | packages/core/my-ui.css:3588-3593 | `.my-image-preview-header[data-my-image-preview]`；`.my-image-preview-footer[data-my-image-preview]`；`.my-image-preview-previous[data-my-image-preview]`；`.my-image-preview-next[data-my-image-preview]` |
| `@media (prefers-reduced-motion: reduce)` | packages/core/my-ui.css:3594-3597 | `.my-image-preview-overlay[data-my-image-preview], .my-image-preview-overlay [data-my-image-preview]` |
| `@media (hover: hover) and (pointer: fine)` | packages/core/my-ui.css:3713-3717 | `.my-tappable-card[data-my-card]:not([data-my-press-input]):hover:not(:active)` |
| `@media (max-width: 1100px)` | packages/core/my-ui.css:3718-3722 | `.my-card[data-my-card]` |
| `@media (max-width: 760px)` | packages/core/my-ui.css:3723-3741 | `.my-card[data-my-card]`；`.my-surface-head h3[data-my-card]`；`.my-surface-head p[data-my-card]`；`.my-surface-head[data-my-card]`；`.my-sample-id[data-my-card]` |
| `@media (max-width: 400px)` | packages/core/my-ui.css:3742-3753 | `.my-surface-head[data-my-card]`；`.my-surface-head h3[data-my-card]`；`.my-sample-id[data-my-card]` |
| `@media (prefers-reduced-motion: reduce)` | packages/core/my-ui.css:3801-3805 | `.my-spinner[data-my-loading]` |
| `@media (prefers-reduced-motion: reduce)` | packages/core/my-ui.css:3852-3856 | `.my-skeleton-visual[data-my-skeleton]` |
| `@media (prefers-reduced-motion: reduce)` | packages/core/my-ui.css:4009-4018 | `.my-pull-refresh-spinner`；`.my-pull-refresh-track, .my-pull-refresh-indicator, .my-pull-refresh-symbol > svg` |
| `@media (hover: hover)` | packages/core/my-ui.css:4093-4098 | `.my-app-bar-back[data-my-app-bar]:hover, .my-upload-action[data-my-upload]:not(:disabled):hover`；`.my-notice-close[data-my-notice]:hover`；`button.my-step-body[data-my-steps]:not(:disabled):hover`；`.my-upload-drop[data-my-upload]:not(:disabled):hover` |
| `@media (prefers-reduced-motion: reduce)` | packages/core/my-ui.css:4099-4101 | `.my-notice[data-my-notice], .my-upload-drop[data-my-upload]` |
