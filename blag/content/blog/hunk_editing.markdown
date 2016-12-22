---
title: "The Art of Manually Editing Hunks"
description: "How to edit hunk diffs"
tags:
  - "Git"
  - "How-to"
  - "Tips and Tricks"
date: "2015-10-24"
updated: "2015-10-24"
categories:
  - "Development"
slug: "art-manually-edit-hunks"
---

There's a certain art to editing hunks, seemingly arcane. Hunks are blocks of
changes typically found in unified diff patch files, or, more commonly today,
found in Git patches.

Git uses its own variant of the [unified diff format][1], but it isn't much
different. The differences between the unified format and Git's are usually not
significant. The patch files created with [`git-show`][4] or [`git-diff`][2]
are consumable by the usual tools, `patch`, `git`, `vimdiff`, etc.

## Short Introduction to Unified Diff ##

A unified diff may look something similar to (freely copied from the
`diffutils` manual):

    --- lao	2002-02-21 23:30:39.942229878 -0800
    +++ tzu	2002-02-21 23:30:50.442260588 -0800
    @@ -1,7 +1,6 @@
    -The Way that can be told of is not the eternal Way;
    -The name that can be named is not the eternal name.
     The Nameless is the origin of Heaven and Earth;
    -The Named is the mother of all things.
    +The named is the mother of all things.
    +
     Therefore let there always be non-being,
       so we may see their subtlety,
     And let there always be being,
    @@ -9,3 +8,6 @@
     The two are the same,
     But after they are produced,
       they have different names.
    +They both may be called deep and profound.
    +Deeper and more profound,
    +The door of all subtleties!

The first two lines define the files that are input into the `diff` program,
the first, `lao`, being the "source" file and the second, `tzu`, being the
"new" file. The starting characters `---` and `+++` denote the lines from each.

`+` denotes a line that will be added to the first file and `-` denotes a line
that will be removed from the first file. Lines with no changes are preceded by
a single space.

The `@@ -1,7 +1,6 @@` and `@@ -9,3 +8,6 @@` are the hunk identifiers. That is,
diff hunks are the blocks identified by `@@ -line number[,context] +line
number[, context] @@` in the diff format. The `context` number is optional and
occasionally not needed. However, it is always included in when using
`git-diff`. The line numbers defines the number the hunk begins. The context
number defines the number of lines in the hunk. Unlike the line number, it
often differs between the two files. In the first hunk of the example above,
the context numbers are `7` and `6`, respectively. That is, lines preceded with
a `-` and a space equals 7. Similarly, lines starting with a `+` and a space
equals 6.

> Lines starting with a space count towards the context of both files.

Since the second file has a smaller context, this means we are removing more
(by one) lines than we are adding. To `diff`, updating a line is the same as
removing the old line and adding a new line (with the changes).

Armed with this information, we can start editing hunks that can be cleanly
applied.

## Motivation ##

What might be the motivation for even wanting to edit hunk files? The biggest I
see is when using `git-add --patch`. Particularly when the changes run together
and cannot be split apart automatically. We can see this in the diff above.

The trivial case is being able to stage a single hunk of the above diff,
nothing has to be done to stage the changes separately other than using the
`--patch` option.

However, staging separate changes inside a hunk becomes slightly more
complicated. Often, if the changes are broken up with a even just a single
line (if it exists), they can be split. When they run together, it becomes more
difficult to do.

Of course, a way to solve this problem, is to manually back out the changes (a
series of "undos"), save the file, stage it, play back the changes (a series of
"redos", perhaps). This can be very error prone and if you make any other
changes during between undo and redo, you may have lost the changes. Therefore,
being able to manually edit the specific hunk into the right shape, no changes
are lost.

## Hunk Editing Example ##

Let's walk through an example of staging some changes, and manually editing a
hunk to stage them into the patches we want.

Create a temporary Git repository, this will be a just some basic stuff for
testing.

    % cd /tmp
    % git init foo
    % cd foo

> From here on, we will assume the working directory to be `/tmp/foo`.

Inside this new Git repository, add a new file, `quicksort.exs`:

    defmodule Quicksort do

      def sort(list) do
        _sort(list)
      end

      defp _sort([]), do: []
      defp _sort(list = [h|t]) do
        _sort(Enum.filter(list, &(&1 < h))) ++ [h] ++ _sort(Enum.filter(list, &(&1 > h)))
      end

    end

Perform the usual actions, `git-add` and `git-commit`:

    % git add quicksort.exs
    % git commit -m 'initial commit'

Now, let's make some changes. For one, there's compiler warning about the
unused variable `t` and the actually sorting seems a bit dense. Let's fix the
warning and breakup the sorting:

    defmodule Quicksort do

      def sort(list) do
        _sort(list)
      end

      defp _sort([]), do: []
      defp _sort(list = [h|_]) do
        (list |> Enum.filter(&(&1 < h)) |> _sort)
        ++ [h] ++
        (list |> Enum.filter(&(&1 > h)) |> _sort)
      end

    end

Saving this version of the file should produce a diff similar to the following:

    diff --git a/quicksort.exs b/quicksort.exs
    index 97b60b4..ed2446b 100644
    --- a/quicksort.exs
    +++ b/quicksort.exs
    @@ -5,8 +5,10 @@ defmodule Quicksort do
       end

       defp _sort([]), do: []
    -  defp _sort(list = [h|t]) do
    -    _sort(Enum.filter(list, &(&1 < h))) ++ [h] ++ _sort(Enum.filter(list, &(&1 > h)))
    +  defp _sort(list = [h|_]) do
    +    (list |> Enum.filter(&(&1 < h)) |> _sort)
    +    ++ [h] ++
    +    (list |> Enum.filter(&(&1 > h)) |> _sort)
       end

     end

However, since these changes are actually, argubly, two different changes, they
should live in two commits. Let's stage the change for `t` to `_`:

    % git add --patch

We will be presented with the diff from before:

    diff --git a/quicksort.exs b/quicksort.exs
    index 97b60b4..ed2446b 100644
    --- a/quicksort.exs
    +++ b/quicksort.exs
    @@ -5,8 +5,10 @@ defmodule Quicksort do
       end

       defp _sort([]), do: []
    -  defp _sort(list = [h|t]) do
    -    _sort(Enum.filter(list, &(&1 < h))) ++ [h] ++ _sort(Enum.filter(list, &(&1 > h)))
    +  defp _sort(list = [h|_]) do
    +    (list |> Enum.filter(&(&1 < h)) |> _sort)
    +    ++ [h] ++
    +    (list |> Enum.filter(&(&1 > h)) |> _sort)
       end

     end
    Stage this hunk [y,n,q,a,d,/,e,?]?

First thing we want to try is using the `split(s)` option. However, this is an
invalid choice because Git does not know how to split this hunk and we will be
presented with the available options and the hunk again. The option we then
want is `edit(e)`.

We will be dropped into our default editor, environment variable `$EDITOR`, Git
`core.editor` setting. From there, we will be presented with something of the
following:

    # Manual hunk edit mode -- see bottom for a quick guide
    @@ -5,8 +5,10 @@ defmodule Quicksort do
       end

       defp _sort([]), do: []
    -  defp _sort(list = [h|t]) do
    -    _sort(Enum.filter(list, &(&1 < h))) ++ [h] ++ _sort(Enum.filter(list, &(&1 > h)))
    +  defp _sort(list = [h|_]) do
    +    (list |> Enum.filter(&(&1 < h)) |> _sort)
    +    ++ [h] ++
    +    (list |> Enum.filter(&(&1 > h)) |> _sort)
       end

     end
    # ---
    # To remove '-' lines, make them ' ' lines (context).
    # To remove '+' lines, delete them.
    # Lines starting with # will be removed.
    #
    # If the patch applies cleanly, the edited hunk will immediately be
    # marked for staging. If it does not apply cleanly, you will be given
    # an opportunity to edit again. If all lines of the hunk are removed,
    # then the edit is aborted and the hunk is left unchanged.

From here, we want to edit the diff to represent only what we care about.

That is, we want the diff to look like:

    @@ -5,8 +5,10 @@ defmodule Quicksort do
       end

       defp _sort([]), do: []
    -  defp _sort(list = [h|t]) do
    +  defp _sort(list = [h|_]) do
     sort(Enum.filter(list, &(&1 < h))) ++ [h] ++ _sort(Enum.filter(list, &(&1 > h)))
       end

     end

Saving and closing the editor now, Git will have staged the desired diff. We
can check the staged changes via `git-diff`:

    % git diff --cached
    diff --git a/quicksort.exs b/quicksort.exs
    index 97b60b4..94a5101 100644
    --- a/quicksort.exs
    +++ b/quicksort.exs
    @@ -5,8 +5,8 @@ defmodule Quicksort do
       end

       defp _sort([]), do: []
    -  defp _sort(list = [h|t]) do
    +  defp _sort(list = [h|_]) do
         _sort(Enum.filter(list, &(&1 < h))) ++ [h] ++ _sort(Enum.filter(list, &(&1 > h)))
       end

     end

Notice, the hunk context data was updated correctly to match the new changes.

From here, commit the first change, and then add and commit the second change.

Something to watch out for is overzealously removing changed lines. For
example, in Elixir quicksort example we have just did, if we entirely removed
the second `-` from the diff _and_ manually updated the hunk header, the patch
will never apply cleanly. Therefore, be especially careful with removing `-`
lines.

[1]: https://www.gnu.org/software/diffutils/manual/html_node/Unified-Format.html

[2]: https://www.kernel.org/pub/software/scm/git/docs/git-diff.html

[3]: https://www.gnu.org/licenses/fdl.html

[4]: https://www.kernel.org/pub/software/scm/git/docs/git-show.html
