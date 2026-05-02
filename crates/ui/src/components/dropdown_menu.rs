use gpui::{Anchor, AnyView, Entity, Pixels, Point};

use crate::{ButtonLike, ContextMenu, PopoverMenu, prelude::*};

use super::PopoverMenuHandle;

#[derive(Debug, Default, Clone, Copy, PartialEq, Eq, Hash)]
pub enum DropdownStyle {
    #[default]
    Solid,
    Outlined,
    Subtle,
    Ghost,
}

enum LabelKind {
    Text(SharedString),
    Element(AnyElement),
}

#[derive(IntoElement, RegisterComponent)]
pub struct DropdownMenu {
    id: ElementId,
    label: LabelKind,
    trigger_size: ButtonSize,
    trigger_tooltip: Option<Box<dyn Fn(&mut Window, &mut App) -> AnyView + 'static>>,
    trigger_icon: Option<IconName>,
    style: DropdownStyle,
    menu: Entity<ContextMenu>,
    full_width: bool,
    disabled: bool,
    handle: Option<PopoverMenuHandle<ContextMenu>>,
    attach: Option<Anchor>,
    offset: Option<Point<Pixels>>,
    tab_index: Option<isize>,
    chevron: bool,
}

impl DropdownMenu {
    pub fn new(
        id: impl Into<ElementId>,
        label: impl Into<SharedString>,
        menu: Entity<ContextMenu>,
    ) -> Self {
        Self {
            id: id.into(),
            label: LabelKind::Text(label.into()),
            trigger_size: ButtonSize::Default,
            trigger_tooltip: None,
            trigger_icon: Some(IconName::ChevronUpDown),
            style: DropdownStyle::default(),
            menu,
            full_width: false,
            disabled: false,
            handle: None,
            attach: None,
            offset: None,
            tab_index: None,
            chevron: true,
        }
    }

    pub fn new_with_element(
        id: impl Into<ElementId>,
        label: AnyElement,
        menu: Entity<ContextMenu>,
    ) -> Self {
        Self {
            id: id.into(),
            label: LabelKind::Element(label),
            trigger_size: ButtonSize::Default,
            trigger_tooltip: None,
            trigger_icon: Some(IconName::ChevronUpDown),
            style: DropdownStyle::default(),
            menu,
            full_width: false,
            disabled: false,
            handle: None,
            attach: None,
            offset: None,
            tab_index: None,
            chevron: true,
        }
    }

    pub fn style(mut self, style: DropdownStyle) -> Self {
        self.style = style;
        self
    }

    pub fn trigger_size(mut self, size: ButtonSize) -> Self {
        self.trigger_size = size;
        self
    }

    pub fn trigger_tooltip(
        mut self,
        tooltip: impl Fn(&mut Window, &mut App) -> AnyView + 'static,
    ) -> Self {
        self.trigger_tooltip = Some(Box::new(tooltip));
        self
    }

    pub fn trigger_icon(mut self, icon: IconName) -> Self {
        self.trigger_icon = Some(icon);
        self
    }

    pub fn full_width(mut self, full_width: bool) -> Self {
        self.full_width = full_width;
        self
    }

    pub fn handle(mut self, handle: PopoverMenuHandle<ContextMenu>) -> Self {
        self.handle = Some(handle);
        self
    }

    /// Defines which corner of the handle to attach the menu's anchor to.
    pub fn attach(mut self, attach: Anchor) -> Self {
        self.attach = Some(attach);
        self
    }

    /// Offsets the position of the menu by that many pixels.
    pub fn offset(mut self, offset: Point<Pixels>) -> Self {
        self.offset = Some(offset);
        self
    }

    pub fn tab_index(mut self, arg: isize) -> Self {
        self.tab_index = Some(arg);
        self
    }

    pub fn no_chevron(mut self) -> Self {
        self.chevron = false;
        self
    }
}

impl Disableable for DropdownMenu {
    fn disabled(mut self, disabled: bool) -> Self {
        self.disabled = disabled;
        self
    }
}

impl RenderOnce for DropdownMenu {
    fn render(self, _window: &mut Window, _cx: &mut App) -> impl IntoElement {
        let button_style = match self.style {
            DropdownStyle::Solid => ButtonStyle::Filled,
            DropdownStyle::Subtle => ButtonStyle::Subtle,
            DropdownStyle::Outlined => ButtonStyle::Outlined,
            DropdownStyle::Ghost => ButtonStyle::Transparent,
        };

        let full_width = self.full_width;
        let trigger_size = self.trigger_size;

        let (text_button, element_button) = match self.label {
            LabelKind::Text(text) => (
                Some(
                    Button::new(self.id.clone(), text)
                        .style(button_style)
                        .when_some(self.trigger_icon.filter(|_| self.chevron), |this, icon| {
                            this.end_icon(
                                Icon::new(icon).size(IconSize::XSmall).color(Color::Muted),
                            )
                        })
                        .when(full_width, |this| this.full_width())
                        .size(trigger_size)
                        .disabled(self.disabled)
                        .when_some(self.tab_index, |this, tab_index| this.tab_index(tab_index)),
                ),
                None,
            ),
            LabelKind::Element(element) => (
                None,
                Some(
                    ButtonLike::new(self.id.clone())
                        .child(element)
                        .style(button_style)
                        .when(self.chevron, |this| {
                            this.child(
                                Icon::new(IconName::ChevronUpDown)
                                    .size(IconSize::XSmall)
                                    .color(Color::Muted),
                            )
                        })
                        .when(full_width, |this| this.full_width())
                        .size(trigger_size)
                        .disabled(self.disabled)
                        .when_some(self.tab_index, |this, tab_index| this.tab_index(tab_index)),
                ),
            ),
        };

        let mut popover = PopoverMenu::new((self.id.clone(), "popover"))
            .full_width(self.full_width)
            .menu(move |_window, _cx| Some(self.menu.clone()));

        popover = match (text_button, element_button, self.trigger_tooltip) {
            (Some(text_button), None, Some(tooltip)) => {
                popover.trigger_with_tooltip(text_button, tooltip)
            }
            (Some(text_button), None, None) => popover.trigger(text_button),
            (None, Some(element_button), Some(tooltip)) => {
                popover.trigger_with_tooltip(element_button, tooltip)
            }
            (None, Some(element_button), None) => popover.trigger(element_button),
            _ => popover,
        };

        popover
            .attach(match self.attach {
                Some(attach) => attach,
                None => Anchor::BottomRight,
            })
            .when_some(self.offset, |this, offset| this.offset(offset))
            .when_some(self.handle, |this, handle| this.with_handle(handle))
    }
}

impl Component for DropdownMenu {
    fn scope() -> ComponentScope {
        ComponentScope::Input
    }

    fn name() -> &'static str {
        "DropdownMenu"
    }

    fn description() -> Option<&'static str> {
        Some(
            "下拉菜单显示操作或选项的列表。下拉菜单始终通过单击触发器（或通过按键绑定）来激活。",
        )
    }

    fn preview(window: &mut Window, cx: &mut App) -> Option<AnyElement> {
        let menu = ContextMenu::build(window, cx, |this, _, _| {
            this.entry("选项 1", None, |_, _| {})
                .entry("选项 2", None, |_, _| {})
                .entry("选项 3", None, |_, _| {})
                .separator()
                .entry("选项 4", None, |_, _| {})
        });

        let menu_with_submenu = ContextMenu::build(window, cx, |this, _, _| {
            this.entry("切换所有停靠栏", None, |_, _| {})
                .submenu("编辑器布局", |menu, _, _| {
                    menu.entry("向上拆分", None, |_, _| {})
                        .entry("向下拆分", None, |_, _| {})
                        .separator()
                        .entry("侧向拆分", None, |_, _| {})
                })
                .separator()
                .entry("项目面板", None, |_, _| {})
                .entry("大纲面板", None, |_, _| {})
                .separator()
                .submenu("自动填充", |menu, _, _| {
                    menu.entry("联系人…", None, |_, _| {})
                        .entry("密码…", None, |_, _| {})
                })
                .submenu_with_icon("预测", IconName::ZedPredict, |menu, _, _| {
                    menu.entry("全部位置", None, |_, _| {})
                        .entry("在光标处", None, |_, _| {})
                        .entry("在这里", None, |_, _| {})
                        .entry("在那里", None, |_, _| {})
                })
        });

        Some(
            v_flex()
                .gap_6()
                .children(vec![
                    example_group_with_title(
                        "基本用法",
                        vec![
                            single_example(
                                "默认",
                                DropdownMenu::new("default", "选择一个选项", menu.clone())
                                    .into_any_element(),
                            ),
                            single_example(
                                "全宽",
                                DropdownMenu::new(
                                    "full-width",
                                    "全宽下拉菜单",
                                    menu.clone(),
                                )
                                .full_width(true)
                                .into_any_element(),
                            ),
                        ],
                    ),
                    example_group_with_title(
                        "子菜单",
                        vec![single_example(
                            "带子菜单",
                            DropdownMenu::new("submenu", "子菜单", menu_with_submenu)
                                .into_any_element(),
                        )],
                    ),
                    example_group_with_title(
                        "风格",
                        vec![
                            single_example(
                                "描边",
                                DropdownMenu::new("outlined", "描边下拉菜单", menu.clone())
                                    .style(DropdownStyle::Outlined)
                                    .into_any_element(),
                            ),
                            single_example(
                                "透明",
                                DropdownMenu::new("ghost", "透明下拉菜单", menu.clone())
                                    .style(DropdownStyle::Ghost)
                                    .into_any_element(),
                            ),
                        ],
                    ),
                    example_group_with_title(
                        "状态",
                        vec![single_example(
                            "禁用",
                            DropdownMenu::new("disabled", "禁用下拉菜单", menu)
                                .disabled(true)
                                .into_any_element(),
                        )],
                    ),
                ])
                .into_any_element(),
        )
    }
}
