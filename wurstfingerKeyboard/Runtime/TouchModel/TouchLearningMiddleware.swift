//
//  TouchLearningMiddleware.swift
//  Wurstfinger
//
//  Observes user `.deleteBackward` actions in the ActionPipeline to drive the
//  acceptance filter's veto (spec §4.1). The pipeline is the single chokepoint
//  for user-initiated deletes (tap/swipe-resolved and slide-delete both call
//  `pipeline.process`); compose/Telex internal deletes call the text target
//  directly and bypass this — exactly as required.
//

import Foundation

struct TouchLearningMiddleware: ActionMiddleware {
    /// Called when a user `.deleteBackward` passes through the pipeline.
    let onUserDelete: () -> Void

    func process(_ context: ActionContext, next: (ActionContext) -> Void) {
        if case .deleteBackward = context.action {
            onUserDelete()
        }
        next(context)
    }
}
