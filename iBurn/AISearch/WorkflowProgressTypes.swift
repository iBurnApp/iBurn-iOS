//
//  WorkflowProgressTypes.swift
//  iBurn
//
//  Lightweight UI state types for AI workflow execution (progress + run state).
//
//  Created by Claude Code on 5/29/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation

/// A single step shown in the AI guide progress list.
struct WorkflowStepProgress: Identifiable {
    let id = UUID()
    let message: String
    var state: StepState

    enum StepState {
        case pending
        case running
        case completed
        case failed
    }
}

/// Overall execution state of an AI workflow run.
enum WorkflowExecutionState {
    case idle
    case running
    case completed
    case failed(String)
}
