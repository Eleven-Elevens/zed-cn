use gpui::{IntoElement, ParentElement};
use ui::{List, ListBulletItem, prelude::*};

/// Centralized definitions for Zed AI plans
pub struct PlanDefinitions;

impl PlanDefinitions {
    pub fn free_plan(&self) -> impl IntoElement {
        List::new()
            .child(ListBulletItem::new("2,000 次已接受的编辑预测"))
            .child(ListBulletItem::new(
                "使用你的 AI API 密钥可无限提示",
            ))
            .child(ListBulletItem::new("无限使用外部 Agent"))
    }

    pub fn pro_trial(&self, period: bool) -> impl IntoElement {
        List::new()
            .child(ListBulletItem::new("Zed Agent 中 $20 的 token 额度"))
            .child(ListBulletItem::new("无限编辑预测"))
            .when(period, |this| {
                this.child(ListBulletItem::new(
                    "可试用 14 天，无需信用卡",
                ))
            })
    }

    pub fn pro_plan(&self) -> impl IntoElement {
        List::new()
            .child(ListBulletItem::new("Zed Agent 中 $5 的 token 额度"))
            .child(ListBulletItem::new("超出 $5 后按用量计费"))
            .child(ListBulletItem::new("无限编辑预测"))
    }

    pub fn business_plan(&self) -> impl IntoElement {
        List::new()
            .child(ListBulletItem::new("无限编辑预测"))
            .child(ListBulletItem::new("按用量计费"))
    }

    pub fn student_plan(&self) -> impl IntoElement {
        List::new()
            .child(ListBulletItem::new("无限编辑预测"))
            .child(ListBulletItem::new("Zed Agent 中 $10 的 token 额度"))
            .child(ListBulletItem::new(
                "可选额度包用于额外用量",
            ))
    }
}
