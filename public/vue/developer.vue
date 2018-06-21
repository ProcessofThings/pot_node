<template>
	<div>
		<v-container fluid>
			<v-layout>
				<v-flex>
					<v-tabs v-model="active" color="accent" dark slider-color="yellow" grow>
						<v-tab v-for="tab in tabs" :key="tab.id" ripple :click="clicktab(active)">
							{{ tab.title }}
						</v-tab>
						<v-tab-item	v-for="tab in tabs" :key="tab.id" >
							<v-card flat v-if="tab.id === 'status'">
								<v-layout row wrap>
									<v-flex xs6>
										<v-card dark color="secondary">
											<v-card-title><h4>Status</h4></v-card-title>
											<v-divider></v-divider>
											<v-list dark>
												<v-list-tile-content v-for="chain in status" :key="chain.id" v-model="status" class="my-3">
													<v-list-tile-title class="ml-3">{{ chain.name }} : {{chain.status}}</v-list-tile-title>
												</v-list-tile-content>
											</v-card-text>
											</v-list>
										</v-card>
									</v-flex>
								</v-layout>
							</v-card>
							<v-card flat v-if="tab.id === 'create'">
								<v-layout row wrap>
									<v-flex xs6>
										<v-form v-model="valid" lazy-validation>
											<v-text-field
												color="accent"
												v-model="name"
												:rules="nameRules"
												:counter="10"
												label="Application Name"
												required
											></v-text-field>
											<v-text-field
												color="accent"
												v-model="description"
												label="Description"
											></v-text-field>
											<v-checkbox
												color="accent"
												v-model="connect"
												label="Public Connection"
												hint="Anyone can connect to your application without your permissions"
											></v-checkbox>
											<v-checkbox
												v-model="sending"
												label="Sending"
												hint="Allow users to send transactions"
											></v-checkbox>
											<v-checkbox
												v-model="receive"
												label="Receive"
												hint="Allow users to receive transactions"
											></v-checkbox>		
											<v-btn
												:disabled="!valid"
												@click="submit">
											submit
											</v-btn>
										</v-form>
									</v-flex>
								</v-layout>
							</v-card>
						</v-tab-item>
					</v-tabs>
				</v-flex>
			</v-layout>
		</v-container>
	</div>
</template>


<script>

store.registerModule('developer', { 
	namespaced: true,
	state: {
		status: ''
	},
	mutations: {
	},
	actions: {
	},
	getters: {
	}
})


module.exports = {
	data: function () {
		return {
			valid: true,
			name: '',
			nameRules: [
			v => !!v || 'Name is required'
			],
			tabs: [
				{id: "status", title: "Status"},
				{id: "create", title: "Create"}
			],
			active: '',
			description: '',
			connect: true,
			sending: true,
			receive: true
		}
	},
   computed: {
		tabName () {
			return this.$store.getters.tabName
		},
		status () {
			return this.$store.getters['main/getStatus']
		}
	},
	methods: {
		clicktab (tabid) {
			if (tabid == 0) {
				return this.$store.getters['main/getStatus']
			}
		},
	
		submit () {
			console.log('Submit')
			socket.send(JSON.stringify({"createApp": {"appName": this.name,
            "appDesc": this.description,
            "appConnect": this.connect,
            "appSending": this.sending,
            "appReceive": this.receive}}))
          // Native form submission is not yet supported
//          axios.post('/v1/api/multichain/createApp', {
//            appName: this.name,
//            appDesc: this.description,
//            appConnect: this.connect,
//            appSending: this.sending,
//            appReceive: this.receive
//          })
      }
	},
	created: function () {
		console.log("onCreate developer")
//		axios.get('/v1/api/multichain/blockchainStatus', {
//			const status = this.$store.getters['main/getStatus']
//			console.log(status)
//		})
	}	
}
</script>
