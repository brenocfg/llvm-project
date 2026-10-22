; REQUIRES: asserts
; RUN: split-file %S/stale-profile-shared-function.ll %t
; RUN: opt %t/input.ll -passes=sample-profile -sample-profile-file=%t/profile.prof -salvage-stale-profile -use-profiled-call-graph=false -debug-only=sample-profile,sample-profile-matcher,sample-profile-impl -disable-output 2>&1 | FileCheck %s
;
; Check sample queries, not just inferred block weights: entry counts can mask
; whether the shared location mapping was actually applied.

; CHECK: Discard conflicting stale profile mappings for foo
; CHECK: Processing Function same.llvm.1
; CHECK: call void @bar(){{.*}}line offset: 2.0 - weight: 300
; CHECK: call void @baz(){{.*}}line offset: 4.0 - weight: 500
; CHECK: Processing Function same
; CHECK: call void @bar(){{.*}}line offset: 2.0 - weight: 300
; CHECK: call void @baz(){{.*}}line offset: 4.0 - weight: 500
; CHECK: Processing Function foo.2
; CHECK: call void @bar(){{.*}}line offset: 3.0 - weight: 300
; CHECK: call void @baz(){{.*}}line offset: 5.0 - weight: 500
; CHECK: Processing Function foo.1
; CHECK: weight[]: 0
; CHECK: Processing Function foo
; CHECK-NOT: call void @bar()
; CHECK-NOT: call void @baz()
; CHECK: Processing Function solo
; CHECK: call void @bar(){{.*}}line offset: 2.0 - weight: 300
; CHECK: call void @baz(){{.*}}line offset: 4.0 - weight: 500
