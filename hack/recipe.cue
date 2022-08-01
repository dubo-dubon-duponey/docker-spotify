package cake

import (
	"duponey.cloud/scullery"
	"duponey.cloud/buildkit/types"
	"strings"
)


cakes: {
  image: scullery.#Cake & {
		recipe: {
			input: {
				from: {
					registry: * "index.docker.io/dubodubonduponey" | string
				}
			}

			process: {
				platforms: types.#Platforms | * [
					types.#Platforms.#AMD64,
					types.#Platforms.#ARM64,
					types.#Platforms.#I386,
					types.#Platforms.#V7,
					types.#Platforms.#V6,
					types.#Platforms.#S390X,
					types.#Platforms.#PPC64LE,
				]
			}

			output: {
				images: {
					names: [...string] | * ["spotify"],
					tags: [...string] | * ["latest"]
				}
			}

			metadata: {
				title: string | * "Dubo Spotify",
				description: string | * "A Spotify connect receiver",
			}
		}
  }
}

injectors: {
	suite: * "bullseye" | =~ "^(?:jessie|stretch|buster|bullseye|sid)$" @tag(suite, type=string)
	date: * "2022-04-01" | =~ "^[0-9]{4}-[0-9]{2}-[0-9]{2}$" @tag(date, type=string)
	platforms: string @tag(platforms, type=string)
	registry: * "registry.local" | string @tag(registry, type=string)
}

cakes: image: recipe: {
	input: from: registry: injectors.registry

	if injectors.platforms != _|_ {
		process: platforms: strings.Split(injectors.platforms, ",")
	}


	output: images: tags: [injectors.suite + "-" + injectors.date, injectors.suite + "-latest", "latest"]
	metadata: ref_name: injectors.suite + "-" + injectors.date
}

// Allow hooking-in a UserDefined environment as icing
UserDefined: scullery.#Icing

cakes: image: icing: UserDefined

