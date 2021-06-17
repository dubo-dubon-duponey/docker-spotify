package cake

import (
	"duponey.cloud/scullery"
	"duponey.cloud/buildkit/types"
	"strings"
)

// XXX WIP: clearly the injector is defective at this point and has to be rethought
// It's probably a better approach to hook it into the recipe, or the env to avoid massive re-use problems

// Entry point if there are environmental definitions
UserDefined: scullery.#Icing & {
	// XXX add injectors here?
//				cache: injector._cache_to
//				cache: injector._cache_from
}

// XXX unfortunately, you cannot have tags in imported packages, so this has to be hard-copied here

defaults: {
	tags: [
		types.#Image & {
			registry: "push-registry.local"
 			image: "dubo-dubon-duponey/aptly"
			// tag: cakes.debian.recipe.process.args.TARGET_SUITE + "-" + cakes.debian.recipe.process.args.TARGET_DATE
		},
		types.#Image & {
			registry: "push-registry.local"
			image: "dubo-dubon-duponey/aptly"
			tag: "latest"
		},
		types.#Image & {
   		registry: "ghcr.io"
   		image: "dubo-dubon-duponey/aptly"
   		// tag: cakes.debian.recipe.process.args.TARGET_SUITE + "-" + cakes.debian.recipe.process.args.TARGET_DATE
   	},
		types.#Image & {
			registry: "ghcr.io"
			image: "dubo-dubon-duponey/aptly"
			tag: "latest"
		}
	],
	platforms: [
		types.#Platforms.#AMD64,
		types.#Platforms.#ARM64,
		types.#Platforms.#I386,
		types.#Platforms.#V7,
		types.#Platforms.#V6,
		types.#Platforms.#S390X,
		types.#Platforms.#PPC64LE,
	]

	suite: "bullseye"
	date: "2021-06-01"
}

injector: {
	_i_tags: * strings.Join([for _v in defaults.tags {_v.toString}], ",") | string @tag(tags, type=string)

	_tags: [for _k, _v in strings.Split(_i_tags, ",") {
		types.#Image & {#fromString: _v}
	}]
	// _tags: [...types.#Image]
	//if _i_tags != "" {
	//}
	//_tags: [for _k, _v in strings.Split(_i_tags, ",") {
	//	types.#Image & {#fromString: _v}
	//}]

	_i_platforms: * strings.Join(defaults.platforms, ",") | string @tag(platforms, type=string)

	_platforms: [...string]

	if _i_platforms == "" {
		_platforms: []
	}
	if _i_platforms != "" {
		_platforms: [for _k, _v in strings.Split(_i_platforms, ",") {_v}]
	}

	_target_suite: * defaults.suite | =~ "^(?:buster|bullseye|sid)$" @tag(target_suite, type=string)
	_target_date: * defaults.date | =~ "^[0-9]{4}-[0-9]{2}-[0-9]{2}$" @tag(target_date, type=string)
}

			// XXX this is really environment instead righty?
			// This to specify if a offband repo is available
			//TARGET_REPOSITORY: #Secret & {
			//	content: "https://apt-cache.local/archive/debian/" + strings.Replace(args.TARGET_DATE, "-", "", -1)
			//}

hooks: {
	context: string @tag(from_context, type=string)
}

cakes: {
  image: scullery.#Cake & {
		recipe: {
			input: {
				from: types.#Image & {#fromString: *"scratch" | string @tag(from_image, type=string)}
			}
			process: {
				platforms: injector._platforms
				args: {
					FROM_IMAGE_BUILDER: "ghcr.io/dubo-dubon-duponey/base:builder-bullseye-2021-06-01"
					FROM_IMAGE_RUNTIME: recipe.input.from.toString
				}
			}
			output: {
				tags: injector._tags
			}
			metadata: {
				// ref_name: process.args.TARGET_SUITE + "-" + process.args.TARGET_DATE,
				title: "Dubo Librespot",
				description: "",
			}
		}

		icing: UserDefined
  }
}
