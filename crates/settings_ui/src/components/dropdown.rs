use std::rc::Rc;

use gpui::{App, ElementId, IntoElement, RenderOnce};
use heck::ToTitleCase as _;
use ui::{
    ButtonSize, ContextMenu, DropdownMenu, DropdownStyle, FluentBuilder as _, IconPosition, px,
};

#[derive(IntoElement)]
pub struct EnumVariantDropdown<T>
where
    T: strum::VariantArray + strum::VariantNames + Copy + PartialEq + Send + Sync + 'static,
{
    id: ElementId,
    current_value: T,
    variants: &'static [T],
    labels: &'static [&'static str],
    should_do_title_case: bool,
    tab_index: Option<isize>,
    on_change: Rc<dyn Fn(T, &mut ui::Window, &mut App) + 'static>,
}

impl<T> EnumVariantDropdown<T>
where
    T: strum::VariantArray + strum::VariantNames + Copy + PartialEq + Send + Sync + 'static,
{
    pub fn new(
        id: impl Into<ElementId>,
        current_value: T,
        variants: &'static [T],
        labels: &'static [&'static str],
        on_change: impl Fn(T, &mut ui::Window, &mut App) + 'static,
    ) -> Self {
        Self {
            id: id.into(),
            current_value,
            variants,
            labels,
            should_do_title_case: true,
            tab_index: None,
            on_change: Rc::new(on_change),
        }
    }

    pub fn title_case(mut self, title_case: bool) -> Self {
        self.should_do_title_case = title_case;
        self
    }

    pub fn tab_index(mut self, tab_index: isize) -> Self {
        self.tab_index = Some(tab_index);
        self
    }
}

impl<T> RenderOnce for EnumVariantDropdown<T>
where
    T: strum::VariantArray + strum::VariantNames + Copy + PartialEq + Send + Sync + 'static,
{
    fn render(self, window: &mut ui::Window, cx: &mut ui::App) -> impl gpui::IntoElement {
        let current_value_label = self.labels[self
            .variants
            .iter()
            .position(|v| *v == self.current_value)
            .unwrap()];

        let context_menu = window.use_keyed_state(current_value_label, cx, |window, cx| {
            ContextMenu::new(window, cx, move |mut menu, _, _| {
                for (&value, &label) in std::iter::zip(self.variants, self.labels) {
                    let on_change = self.on_change.clone();
                    let current_value = self.current_value;
                    menu = menu.toggleable_entry(
                        localized_dropdown_label(label, self.should_do_title_case),
                        value == current_value,
                        IconPosition::End,
                        None,
                        move |window, cx| {
                            on_change(value, window, cx);
                        },
                    );
                }
                menu
            })
        });

        DropdownMenu::new(
            self.id,
            localized_dropdown_label(current_value_label, self.should_do_title_case),
            context_menu,
        )
        .when_some(self.tab_index, |elem, tab_index| elem.tab_index(tab_index))
        .trigger_size(ButtonSize::Medium)
        .style(DropdownStyle::Outlined)
        .offset(gpui::Point {
            x: px(0.0),
            y: px(2.0),
        })
        .into_any_element()
    }
}

fn localized_dropdown_label(label: &str, should_do_title_case: bool) -> String {
    let display_label = if should_do_title_case {
        label.to_title_case()
    } else {
        label.to_string()
    };

    match display_label.as_str() {
        "Platform Default" => "平台默认".to_string(),
        "Add to Existing Window" | "Add To Existing Window" => "添加到现有窗口".to_string(),
        "Open a New Window" | "Open A New Window" => "打开新窗口".to_string(),
        "Close Window" => "关闭窗口".to_string(),
        "Keep Window Open" => "保持窗口打开".to_string(),
        "Quit App" => "退出应用".to_string(),
        "Light" => "浅色".to_string(),
        "Dark" => "深色".to_string(),
        "System" => "跟随系统".to_string(),
        "Enabled" => "已启用".to_string(),
        "Disabled" => "已禁用".to_string(),
        "Always" => "始终".to_string(),
        "Never" => "从不".to_string(),
        "On" => "开启".to_string(),
        "Off" => "关闭".to_string(),
        "Left" => "左侧".to_string(),
        "Right" => "右侧".to_string(),
        "Bottom" => "底部".to_string(),
        "Center" => "居中".to_string(),
        "None" => "无".to_string(),
        "Auto" => "自动".to_string(),
        "Subpixel" => "亚像素".to_string(),
        "Grayscale" => "灰度".to_string(),
        _ => display_label,
    }
}
