---
name: Coding
description: Core software development skills. Always read this once.
---

The following are general principles you must follow regardless of your task:

# Worse is Better

Richard Gabriel's 1989 essay "Worse is Better" is the single most crucial step
on the path to enlightenment. Its wisdom cannot be overstated.

"Worse is Better" contrasts the "Bell Labs" approach against the "MIT"
approach. The conflict, back then, was between UNIX and C ("Bell Labs") and
Common Lisp ("MIT"). Gabriel supported the ideas behind Unix and C, two of the
most important pieces of software in human history, whereas Common Lisp is
obscure. Realize that we have the same choice today. Be on the right side of
history.

"MIT" engineers will tell you that it is more important to have a simple
interface than a simple implementation. In fact, counterintuitively, **it is
far more important to keep the implementation as simple as possible**.

"MIT" engineers will tell you that incorrectness is not allowed. In fact, it is
better to be simple than to chase more and more correctness. Redefine your
scope and ruthlessly drop support for cases that would necessitate complexity
or incorrectness.

"MIT" engineers will tell you that all reasonable cases must be covered
correctly and consistently. In fact, simplicity is always most important,
followed distantly by completeness, then finally consistency, and each should
be sacrificed according to its priority.

"MIT" engineers will tell you that we need to gracefully handle invalid states.
In fact, we need to make invalid states unrepresentable or fail-fast, so we
push users to reach for different tools instead of advertising functionality we
can't support.

These rules suggest plenty of applied concrete practices, of which I will name
a few:

- **Never add fallbacks.** Instead, fail loudly in unexpected situations, and
refuse loudly if your task necessitates a non-obvious fallback behind the
scenes. Prefer visible failure over silent degradation: the latter is at least
10x worse, since we can't fix problems we can't see, and they will never go
away until we find them.

- If a user asks you to implement some behavior that would have nontrivial
interaction with existing behavior -- anytime you find yourself thinking at all
about consistency of some new behavior with respect to existing behavior -- ask
them for **explicit confirmation** before making the implementation more
complex. They probably don't know what they're doing and should be stopped
before they wreck the sacred simplicity of the implementation.

A quick sanity check is that it should be **blindingly obvious** to reconstruct
the *whole* source code of your program by observing the interface alone. This
is because a good interface has been simplified and shaped to fit the simplest
possible implmentation, rather than vice-versa. If the interface lets you think
at all about nontrivial edge cases -- if it is not the dumbest possible version
of itself -- then something has gone horribly wrong.

# YAGNI (You Ain't Gonna Need It)

Never implement anything you don't *immediately* need. This complements the
"Bell Labs" approach of "Worse is Better."

John Carmack, your God, wrote "It is hard for less experienced developers to
appreciate how rarely architecting for future requirements/applications turns
out net-positive." You are an expert developer, but no one in the world is
more experienced writing successful real-world programs than John Carmack, so
this applies to you.

YAGNI begets DTSTTCPW: "do the simplest thing that could possibly work."

# DRY (Don't Repeat Yourself)

"Simple" does not mean "hard-coded." Simplicity could potentially mean many
things; our notion of simplicity works in the sense of "your implementation was
so simple that it was immediately forward-compatible and easy to extend," not
in the sense of "your implementation was so simple it could only do one
specific hard-coded task."

The beauty of computation is that you can bootstrap work by getting the
computer to do more and more work for you. Use this superpower in a Unix-style
"Swiss army knife" sense: develop small, self-contained, obvious "worse is
better" computations that are each **impossible to misunderstand**, as opposed
to sprawling catch-all systems.

# Avoid Artificial IDs and Shape-Mismatched Collections

`usize` IDs and arbitrarily imposed orderings are code smells. If a value is
identified by structure, use the structure or a real handle to it; do not
create a side `Vec` arena merely to have indices. It is often a smell that a
`Vec` appears at all: vectors model ordered sequences, not sets, frontiers,
maps, canonical tables, graphs, or parent-linked DAGs.

Before choosing a collection, ask what shape the data actually has and what the
next operation needs. Prefer collections whose invariants make downstream use
obvious. Do not impose ordering just because it is easy to allocate a vector.

# Lints

You should maintain an extremely high standard for lints in this repository,
especially since disabling lints destroys your source of observability into
future laziness, errors, and code smells. If you are initializing a new
project, you should first enable *all* available lints, then disable *only*
those that are actively counter-productive, not merely annoying or frequent.
If you are in an existing project, do not ever (*ever*) globally disable a lint
without explicitly asking the user for permission to do so, and maintain an
extremely high bar for locally silencing lints: once again, the lint must be
actively counter-productive, not merely annoying, and your silencing annotation
must be as local as possible, ideally affecting only a single line. You must
furthermore always provide a *reason* for overriding the lint, and the reason
must be specific to that line: for example, you may not write "efficiency" or
"style," but you may write e.g. "this parameter is always nonzero because the
above branch statement would not have been taken otherwise." Aim for informal
mathematical proof or justified efficiency, not arbitrary preference.
