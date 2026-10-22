; RUN: split-file %s %t
; RUN: opt %t/input.ll -passes=sample-profile -sample-profile-file=%t/profile.prof -salvage-stale-profile -use-profiled-call-graph=false -S -o %t/output.ll
; RUN: FileCheck %s --check-prefix=IR < %t/output.ll
; RUN: opt %t/input.ll -passes=sample-profile -sample-profile-file=%t/profile.prof -salvage-stale-profile -report-profile-staleness -persist-profile-staleness -disable-output 2>&1 | FileCheck %s --check-prefix=STATS
; RUN: llvm-profdata merge --sample --extbinary %t/profile.prof -o %t/profile.extbinary
; RUN: opt %t/input.ll -passes=sample-profile -sample-profile-file=%t/profile.extbinary -salvage-stale-profile -use-profiled-call-graph=false -S | FileCheck %s --check-prefix=IR
; RUN: sed -e 's/@foo.1()/@temporary()/g' -e 's/@foo()/@foo.1()/g' -e 's/@temporary()/@foo()/g' %t/input.ll > %t/reversed.ll
; RUN: opt %t/reversed.ll -passes=sample-profile -sample-profile-file=%t/profile.prof -salvage-stale-profile -use-profiled-call-graph=false -S | FileCheck %s --check-prefix=REVERSED
;
; Suffix elision lets distinct IR functions share one profile. Their location
; maps must be computed independently. Incompatible maps must not be applied
; to either function, while an unambiguous function still gets its remapping.
; Identical nonempty maps can still be shared, including with selected suffix
; elision. An empty (identity) map also participates in the compatibility check.

; IR-LABEL: define internal void @foo()
; IR: call void @bar()
; IR-LABEL: define internal void @foo.1()
; IR-NEXT: call void @bar(), !dbg !{{[0-9]+}}{{$}}
; IR-NEXT: call void @baz(), !dbg !{{[0-9]+}}{{$}}
; IR-LABEL: define internal void @foo.2()
; IR: call void @bar()
; IR-LABEL: define void @solo()
; IR: call void @bar(), !dbg !{{[0-9]+}}, !prof ![[WEIGHT:[0-9]+]]
; IR-LABEL: define internal void @same()
; IR: call void @bar(), !dbg !{{[0-9]+}}, !prof ![[WEIGHT]]
; IR-LABEL: define internal void @same.llvm.1()
; IR: call void @bar(), !dbg !{{[0-9]+}}, !prof ![[WEIGHT]]
; IR: ![[WEIGHT]] = !{!"branch_weights", i32 101}
; REVERSED-LABEL: define internal void @foo()
; REVERSED-NEXT: call void @bar(), !dbg !{{[0-9]+}}{{$}}
; REVERSED-NEXT: call void @baz(), !dbg !{{[0-9]+}}{{$}}
; REVERSED-LABEL: define internal void @foo.2()
; REVERSED: call void @bar(), !dbg !{{[0-9]+}}, !prof
; STATS: (6/12) of callsites' profile are invalid and (2400/6000) of samples are discarded due to callsite location mismatch.
; STATS-NEXT: (6/6) of callsites and (2400/2400) of samples are recovered by stale profile matching.

;--- profile.prof
foo:1000:100
 3: 300 bar:300
 5: 500 baz:500
solo:1000:100
 3: 300 bar:300
 5: 500 baz:500
same:1000:100
 3: 300 bar:300
 5: 500 baz:500

;--- input.ll
declare void @bar()
declare void @baz()

define internal void @foo() #0 !dbg !10 {
  call void @bar(), !dbg !13
  call void @baz(), !dbg !14
  ret void, !dbg !15
}

define internal void @foo.1() #0 !dbg !20 {
  call void @bar(), !dbg !23
  call void @baz(), !dbg !24
  ret void, !dbg !25
}

define internal void @foo.2() #0 !dbg !30 {
  call void @bar(), !dbg !33
  call void @baz(), !dbg !34
  ret void, !dbg !35
}

define void @solo() #0 !dbg !40 {
  call void @bar(), !dbg !43
  call void @baz(), !dbg !44
  ret void, !dbg !45
}

define internal void @same() #1 !dbg !60 {
  call void @bar(), !dbg !63
  call void @baz(), !dbg !64
  ret void, !dbg !65
}

define internal void @same.llvm.1() #1 !dbg !70 {
  call void @bar(), !dbg !73
  call void @baz(), !dbg !74
  ret void, !dbg !75
}

define void @main() #0 !dbg !50 {
  call void @foo(), !dbg !51
  call void @foo.1(), !dbg !52
  call void @foo.2(), !dbg !53
  call void @solo(), !dbg !54
  call void @same(), !dbg !54
  call void @same.llvm.1(), !dbg !54
  ret void, !dbg !55
}

attributes #0 = { noinline "use-sample-profile" }
attributes #1 = { noinline "use-sample-profile" "sample-profile-suffix-elision-policy"="selected" }

!llvm.dbg.cu = !{!0, !1}
!llvm.module.flags = !{!3}

!0 = distinct !DICompileUnit(language: DW_LANG_C, file: !2, producer: "clang", isOptimized: true, emissionKind: LineTablesOnly)
!1 = distinct !DICompileUnit(language: DW_LANG_C, file: !5, producer: "clang", isOptimized: true, emissionKind: LineTablesOnly)
!2 = !DIFile(filename: "a.c", directory: "/")
!5 = !DIFile(filename: "b.c", directory: "/")
!3 = !{i32 2, !"Debug Info Version", i32 3}
!6 = !DISubroutineType(types: !{})

!10 = distinct !DISubprogram(name: "foo", scope: !2, file: !2, line: 1, type: !6, scopeLine: 1, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !0)
!13 = !DILocation(line: 3, scope: !10)
!14 = !DILocation(line: 5, scope: !10)
!15 = !DILocation(line: 6, scope: !10)

!20 = distinct !DISubprogram(name: "foo", scope: !5, file: !5, line: 1, type: !6, scopeLine: 1, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !1)
!23 = !DILocation(line: 5, scope: !20)
!24 = !DILocation(line: 7, scope: !20)
!25 = !DILocation(line: 8, scope: !20)

!30 = distinct !DISubprogram(name: "foo", scope: !5, file: !5, line: 1, type: !6, scopeLine: 1, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !1)
!33 = !DILocation(line: 4, scope: !30)
!34 = !DILocation(line: 6, scope: !30)
!35 = !DILocation(line: 7, scope: !30)

!40 = distinct !DISubprogram(name: "solo", scope: !2, file: !2, line: 1, type: !6, scopeLine: 1, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !0)
!43 = !DILocation(line: 3, scope: !40)
!44 = !DILocation(line: 5, scope: !40)
!45 = !DILocation(line: 6, scope: !40)

!50 = distinct !DISubprogram(name: "main", scope: !2, file: !2, line: 10, type: !6, scopeLine: 10, spFlags: DISPFlagDefinition | DISPFlagOptimized, unit: !0)
!51 = !DILocation(line: 11, scope: !50)
!52 = !DILocation(line: 12, scope: !50)
!53 = !DILocation(line: 13, scope: !50)
!54 = !DILocation(line: 14, scope: !50)
!55 = !DILocation(line: 15, scope: !50)

!60 = distinct !DISubprogram(name: "same", scope: !2, file: !2, line: 1, type: !6, scopeLine: 1, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !0)
!63 = !DILocation(line: 3, scope: !60)
!64 = !DILocation(line: 5, scope: !60)
!65 = !DILocation(line: 6, scope: !60)

!70 = distinct !DISubprogram(name: "same", linkageName: "same.llvm.1", scope: !5, file: !5, line: 1, type: !6, scopeLine: 1, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !1)
!73 = !DILocation(line: 3, scope: !70)
!74 = !DILocation(line: 5, scope: !70)
!75 = !DILocation(line: 6, scope: !70)
