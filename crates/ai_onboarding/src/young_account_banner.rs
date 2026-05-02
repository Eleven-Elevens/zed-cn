use gpui::{IntoElement, ParentElement};
use ui::{Banner, prelude::*};

#[derive(IntoElement)]
pub struct YoungAccountBanner;

impl RenderOnce for YoungAccountBanner {
    fn render(self, _window: &mut Window, cx: &mut App) -> impl IntoElement {
        const YOUNG_ACCOUNT_DISCLAIMER: &str = "为防止服务被滥用，创建时间不足 30 天的 GitHub 账号不能试用 Pro。你可以联系 billing-support@zed.dev 申请例外。";

        let label = div()
            .w_full()
            .text_sm()
            .text_color(cx.theme().colors().text_muted)
            .child(YOUNG_ACCOUNT_DISCLAIMER);

        div()
            .max_w_full()
            .my_1()
            .child(Banner::new().severity(Severity::Warning).child(label))
    }
}
