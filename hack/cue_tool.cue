package cake

import (
	"duponey.cloud/scullery"
	"duponey.cloud/buildkit/types"
)

// This defines our targets for this specific repository:
// a. "debootstrap": build rootfs for a target suite and date, from a local tooling rootfs or a remote image
// This is what you want to do
// b. "debian": generate and push a final, usable, debian image from the debootstrapped rootfs

_no_cache: *false | bool @tag(no_cache,type=bool)
_progress: *types.#Progress.#AUTO | string @tag(progress,type=string)

for _k, _v in cakes {
	command: "\(_k)": scullery.#Oven & {
		cake: _v
		no_cache: _no_cache
		progress: _progress
	}
}
