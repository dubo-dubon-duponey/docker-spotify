package scullery

import (
	"duponey.cloud/buildkit/types"
)
// XXX buildkit oddity - FROM_IMAGE is not used (directly or indirectly) by this specific target, yet buildkit insist that it is defined and not blank

// Status: functional, complete - needs a type review, and a thorough review of default values behavior

// #Date: =~ "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"

// This defines properties of the image
// Some of that may be changed through injects, or environment variables
#Recipe: {
	// Controls from what we are building, with what context - isn't this environment instead?
	input: {
		root: types.#Path | * "./"
		context: types.#Path
		from: types.#Image
		dockerfile?: types.#FilePath
		// XXX this should be an array
		// XXX this should be injectable
		// cache?: types.#CacheFrom
	}

	// Controls for which platform, and what target
	// XXX secret provider?
	process: {
		platforms?: types.#Platforms
		target?: types.#Identifier
		// Backdoor into image specific arguments and secrets
		args: types.#Args
		secrets: types.#Secrets
	}

	// Controls the output: tags to push, directories, tarballs
	output: {
		tags?: [...types.#Image]
		directory?: types.#Path
		tarball?: types.#Tarball
		// XXX this should be an array
		// XXX this should be injectable
		// cache?: types.#CacheTo
	}

	// Standard metadata for the image - XXX this has nothing to do here
	metadata: {
		created: string | * "1976-04-14"
		authors: =~ "^[^<]+ <[^>]+>$" | * "Dubo Dubon Duponey <dubo-dubon-duponey@farcloser.world>"
		url: types.#URL | *"https://github.com/dubo-dubon-duponey/unknown"
		documentation: types.#URL | *"\(url)/blob/master/README.md"
		source: types.#URL | *"\(url)/tree/master"
		version: string | *"unknown",
		revision: string | *"unknown",
		vendor: string | *"dubodubonduponey",
		licenses: string | *"MIT",
		ref_name: string | *"latest",
		title: string | *"Dubo Image",
		description: string | *"A long description for an intriguing Dubo image",
	}
}
