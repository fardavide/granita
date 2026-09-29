# `record-snapshots` deletes the directory first, and that is a trap with uncommitted baselines in it

It opens with `rm -rf __Snapshots__`. Anything in there that git does not track is gone — and a
baseline recorded but not yet committed is exactly that. Sixteen of them were lost that way in one
run, after which `git checkout` restored the 920 tracked ones and could not restore the rest.

**Commit new baselines before running it again**, and after any record, `git status` the directory:
only the subjects that were added should appear. The pass rewrites every animated state — anything
with a spinner or an in-flight bar — at a different frame, so a one-subject addition otherwise arrives
as a hundred-and-thirty-file diff that nobody will review.

