// SPDX-License-Identifier: MIT
// Adapted from vincilawyer/ScreenEdge, commit 7e418d6352b5a839bd01f4b723f54f3f4d5d9e1c.
// Copyright (c) 2026 ScreenEdge contributors. See LICENSES/ScreenEdge-MIT.txt.
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// Read only. The callback is delivered once on the main queue, including timeout and failure.
void SEReadUniversalControlEdges(void (^completion)(NSArray<NSDictionary *> * _Nullable edges, NSString * _Nullable error));
NS_ASSUME_NONNULL_END
