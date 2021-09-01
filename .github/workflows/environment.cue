package cake

import (
	"duponey.cloud/scullery"
)

UserDefined: scullery.#Icing & {
	buildkit: {
		address: string @tag(bk, type=string)
	}
	hosts: {
		// This allows usage of the apt-front with mTLS
		"snapshot.debian.org": {
			ip: string @tag(ip, type=string)
		}
	}
	subsystems: {
		apt: {
			// proxy: string @tag(apt_proxy, type=string)
			user_agent: "DuboDubonDuponey/1.0 (apt)"
			check_valid: false
		}
		curl: {
			user_agent: "DuboDubonDuponey/1.0 (curl)"
		}
	}
	trust: {
		authority: string @tag(trust, type=string)
	}
}
