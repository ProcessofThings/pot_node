<template>
	<div>
		<v-container fluid>
			<v-layout row wrap>
				<v-flex>
						<v-flex>
							<v-select
							color="accent"
							:items="items"
							v-model="blockChain"
							label="Choose Blockchain"
							class="input-group--focused"
							item-text="text"
							item-value="value"
							@change="changedBlockchain"
							></v-select>
						</v-flex>
				</v-flex>
			</v-layout>
			<v-layout>
				<v-flex>
					<v-tabs v-model="active" color="accent" dark slider-color="yellow" grow>
					
						<v-tab v-for="tab in tabs" :key="tab.id" ripple :click="loadData(active)">
							{{ tab.title }}
						</v-tab>
						
						<v-tab-item	v-for="tab in tabs" :key="tab.id">
							<v-card flat>
								<v-container grid-list-md text-xs-center>
									<v-layout row wrap>
										<v-flex xs6>
											<v-card dark color="secondary">
												<v-card-title><h4>My Node</h4></v-card-title>
												<v-divider></v-divider>
												<v-card-text v-for="(value, key) in mynode">
													{{ key }}: {{ value }}
												</v-card-text>
											</v-card>
											<v-card dark color="secondary">
												<v-card-title><h4>Connected Nodes</h4></v-card-title>
												<v-card-text class="px-0">6</v-card-text>
											</v-card>
										</v-flex>
										<v-flex xs6>
											<v-card dark color="secondary">
												<v-card-title><h4>My Addresses</h4></v-card-title>
												<v-card-text class="px-0">6</v-card-text>
											</v-card>											
										</v-flex>
									</v-layout>
								</v-container>
							</v-card>
						</v-tab-item>
					</v-tabs>
				</v-flex>
			</v-layout>
		</v-container>
	</div>
</template>

<script>

store.registerModule('explore', { 
	state: {
		loadedBlockchains: [{"text":"testchain","value":"129FFFEE2DC011E8BC59DF39C410AFD3"},{"text":"pot","value":"C9AF3F5620B911E8A0510CD5963D4F80"}],
		newMynode: '',
		mynode: [],
		loadedMynode: false
	},
	mutations: {
		setGetInfo (state, mynode) {
			state.mynode = mynode
		},
		setloadedBlockchains (state, loadedBlockchains) {
			state.loadedBlockchains = loadedBlockchains
		},
		clearGetInfo (state) {
			state.newMynode = ''
		},
		setloadedMynode (state, mystate) {
			state.loadedMynode = mystate
		}
	},
	actions: {
		loadGetInfo (context, blockChain) {
			console.log(context)
			if (context.state.loadedMynode == false) {
				if (blockChain) {
					fetch('/v1/api/multichain/getinfo/' + blockChain)
						.then(response => response.json())
						.then(json => {
							context.commit('setloadedMynode', true)
							context.commit('setGetInfo', json.result)
						})
				} else {
						context.commit('setloadedMynode', false)
				}
			}
		},
		clearGetInfo ({ commit }) {
			commit(clearGetInfo)
		}
	},
	getters: {
		loadedBlockchains (state) {
			return state.loadedBlockchains
		},
		newMynode: state => state.newMynode,
		mynode: state => state.mynode,
		loadedMynode (state) {
			return state.loadedMynode
		}
	}
})


module.exports = {
	data: function () {
		return {
			active: '',
			blockChain: '',
			value: '',
			tab: null,
			tabs: [
				{id: "node", title: "Node", text: "one"},
				{id: "permisssions", title: "Permissions", text: "two"},
				{id: "stream", title: "View Stream", text: "three"}
			],
			infos: []
		}
	},
   computed: {
		newMynode () {
			return this.$store.getters.newMynode
		},
		mynode () {
			return this.$store.getters.mynode
		},
		items () {
			return this.$store.getters.loadedBlockchains
		},
		loadedMynode () {
			return this.$store.getters.loadedMynode
		}
	},
	methods: {
		loadData (tab) {
			console.log(this.blockChain)
			this.$store.dispatch('loadGetInfo',this.blockChain)
		},
		changedBlockchain () {
			console.log("Changed Blockchain ID")
			this.$store.commit('setloadedMynode', false)		
		}
	},
	created: function () {
	}	
}
</script>
