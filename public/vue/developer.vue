<template>
	<div>
		<v-container fluid>
			<v-layout>
				<v-flex xs12>
					<v-tabs v-model="active" color="accent" dark slider-color="yellow" grow>
						<v-tab v-for="tab in tabs" :key="tab.id" ripple>
							{{ tab.title }}
						</v-tab>
						<v-tab-item	v-for="tab in tabs" :key="tab.id" >
							<v-card flat v-if="tab.id === '0'">
								<v-list two-line subheader>
									<v-subheader inset>Decentralised Applications (DApps)</v-subheader>
									<v-list-tile v-for="chain in myStatus" :key="chain.id" avatar @click="">
										<v-list-tile-avatar>
											<v-icon :class=["chain.icon"]>{{ chain.icon }}</v-icon>
										</v-list-tile-avatar>

										<v-list-tile-content>
											<v-list-tile-title>{{ chain.name }}</v-list-tile-title>
											<v-list-tile-sub-title>{{ chain.id }}</v-list-tile-sub-title>
										</v-list-tile-content>
					
											<v-list-tile-action v-if="chain.id != 'C9AF3F5620B911E8A0510CD5963D4F80'">
												<v-btn icon ripple v-if="chain.status == 'Running'" v-on:click="changeState(chain.id)">
													<v-icon color="grey lighten-1">pause</v-icon>
												</v-btn>
												<v-progress-circular indeterminate color="accent" v-else-if="chain.status != 'Running' && chain.status != 'Stopped'"></v-progress-circular>
												<v-btn icon ripple v-else v-on:click="changeState(chain.id)">
													<v-icon color="grey lighten-1">play_arrow</v-icon>
												</v-btn>
											</v-list-tile-action>
											<v-list-tile-action v-if="chain.id != 'C9AF3F5620B911E8A0510CD5963D4F80'">
												<v-btn icon ripple v-if="chain.status == 'Running'" v-on:click="inviteMobile(chain.id)">
													<v-icon color="grey lighten-1">person_add</v-icon>
												</v-btn>
												<v-progress-circular indeterminate color="yellow" v-else-if="chain.status != 'Running' && chain.status != 'Stopped'"></v-progress-circular>
												<v-btn icon ripple v-else v-on:click="deleteApp(chain.id)">
													<v-icon color="grey lighten-1">delete</v-icon>
												</v-btn>
											</v-list-tile-action>
									</v-list-tile>
								</v-list>
							</v-card>
							<v-card flat v-if="tab.id === '1'">
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
							</v-card>
						</v-tab-item>
					</v-tabs>
				</v-flex>
			</v-layout>
			<v-dialog v-model="dialog" width="200">
				<v-card>
					<v-card-title class="headline grey lighten-2" primary-title>
						Invite Mobile
					</v-card-title>
					<img :src="img" width="100%">

					<v-divider></v-divider>

					<v-card-actions>
						<v-spacer></v-spacer>
						<v-btn
							color="primary"
							flat
							@click="dialog = false"
						>
							Close
						</v-btn>
					</v-card-actions>
				</v-card>
			</v-dialog>
		</v-container>
	</div>
</template>


<script type="text/babel">

store.registerModule('developer', { 
	namespaced: true,
	state: {
		updateStatus: false,
		status: '',
		img: ''
	},
	mutations: {
		loadStatus (state, status) {
			state.status = status
		},
		changeStatus (state, payload) {
			state.status[payload.blockChainId].status = payload.status
		}
	},
	actions: {
		loadStatus (context, payload) {
          context.commit('loadStatus', payload)
		},
		getStatus ({state, rootState, rootGetters}) {
			console.log(rootGetters)
			store.dispatch('developer/loadStatus', rootGetters['main/getStatus'])
		},
		changeStatus ({state, rootState}, payload) {
			console.log(rootState)
			console.log(payload)
			store.commit('developer/changeStatus', payload)
		}
	},
	getters: {
		getStatus (state) {
			return state.status
		},
		updateStatus (state) {
			return state.updateStatus
		}
	}
})

store.subscribe((mutation, state) => {
	if (mutation.type == 'main/statusStore') {
		store.dispatch('developer/loadStatus', mutation.payload)
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
				{id: "0", title: "Status"},
				{id: "1", title: "Create"}
			],
			active: '',
			description: '',
			connect: true,
			sending: true,
			receive: true,
			dialog: false,
			img: ''
		}
	},
   computed: {
		myStatus () {
			console.log("computered myStatus")
			return this.$store.getters['developer/getStatus']
		},
		updateStatus () {
			return this.$store.getters['developer/updateStatus']
		}
   },
	methods: {
		submit () {
			console.log('Submit')
			// store.dispatch('main/sendMessage', '')
			// Native form submission is not yet supported
			axios.post('/v1/api/multichain/createApp', {
				appName: this.name,
				appDesc: this.description,
				appConnect: this.connect,
				appSending: this.sending,
				appReceive: this.receive
			})
      },
      changeState (id) {
			console.log(id)
			store.dispatch('developer/changeStatus', {blockChainId: id, status: "waiting"})
			axios.post('/v1/api/multichain/changeAppState/' + id, {
				blockChainId: id
			})
      },
		deleteApp (id) {
			console.log(id)
			store.dispatch('developer/changeStatus', {blockChainId: id, status: "waiting"})
			axios.post('/v1/api/multichain/deleteApp/' + id, {
				blockChainId: id
			})
      },
      inviteMobile (id) {
			axios.get('/v1/api/multichain/inviteMobile/' + id, {
				blockChainId: id
			})
			.then(res => {
				const data = res.data
				this.$data.img = res.data.image
				this.$data.dialog = true
				console.log(data)
			})
			.catch(function (error) {
				console.log(error);
			})
      }
	},
	created: function () {
		console.log("onCreate developer")
		this.$store.dispatch('developer/getStatus')
	}	
}
</script>
