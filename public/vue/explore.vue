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
							placeholder="Please Choose One"
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
							<v-card flat v-if="tabName === 'node'">
								<v-container grid-list-md text-xs-center>
									<v-layout row wrap>
										<v-flex xs6>
											<v-card dark color="secondary">
												<v-card-title><h4>My Node</h4></v-card-title>
												<v-divider></v-divider>
												<v-list dark two-line>
													<v-list-tile-content v-for="(value, key) in mynode" class="my-3">
														<v-list-tile-title class="ml-3">{{ key }}</v-list-tile-title>
														<v-list-tile-sub-title class="ml-5">{{ value }}</v-list-tile-sub-title>
													</v-list-tile-content>
												</v-card-text>
												</v-list>
											</v-card>
											
											<v-card v-if="connectedNodes" dark color="secondary">
												<v-card-title><h4>Connected Nodes</h4></v-card-title>
												<v-expansion-panel>
													<v-expansion-panel-content v-for="connectedNode in connectedNodes">
														<div slot="header">Peer : {{ connectedNode.Address }}</div>
														<v-card dark color="secondary">
															<v-divider v-for="connectedNode in connectedNodes"></v-divider>
																<v-list dark two-line>
																	<v-list-tile-content class="my-3">
																		<v-list-tile-title class="ml-3">Latency</v-list-tile-title>
																		<v-list-tile-sub-title class="ml-5">{{ connectedNode.Latency }}</v-list-tile-sub-title>
																		<v-list-tile-title class="ml-3">Blocks</v-list-tile-title>
																		<v-list-tile-sub-title class="ml-5">{{ connectedNode.Blocks }}</v-list-tile-sub-title>
																		</v-list-tile>
																	</v-list-tile-content>
																</v-list>
														</v-card>
													</v-expansion-panel-content>
												</v-expansion-panel>
											</v-card>
										</v-flex>
										<v-flex xs6>
											<v-card dark color="secondary">
												<v-card-title><h4>My Addresses</h4></v-card-title>
												<v-divider></v-divider>
												<v-list dark two-line>
													<v-list-tile v-for="address in addresses">
														<v-list-tile-content class="my-3">
															<v-list-tile-title class="ml-3">Address</v-list-tile-title>
															<v-list-tile-sub-title class="ml-5">{{address}}</v-list-tile-sub-title>
														</v-list-tile-content>
													 </v-list-tile>
												</v-list>
											</v-card>											
										</v-flex>
									</v-layout>
								</v-container>
							</v-card>
							<v-card flat v-if="tabName === 'permissions'">
								<v-container grid-list-md text-xs-center>
									<v-layout row wrap>
										<v-flex xs6>
											<v-card dark color="secondary">
												<v-card-title><h4>Current Permissions</h4></v-card-title>
												<v-divider></v-divider>
												<v-list dark two-line>
													<v-list-tile-content class="my-3" v-for="listPermission in listPermissions">
														<v-list-tile-title class="ml-3">Address : {{listPermission.address}}</v-list-tile-title>
														<v-list-tile-sub-title class="ml-5">Permissions</v-list-tile-sub-title>
													</v-list-tile-content>
												</v-card-text>
												</v-list>
											</v-card>
										</v-flex>
										<v-flex xs6>
											<v-card dark color="secondary">
												<v-card-title><h4>Change Permissions</h4></v-card-title>
												<v-divider></v-divider>
											</v-card>											
										</v-flex>
									</v-layout>
								</v-container>
							</v-card>
							<v-card flat v-if="tabName === 'stream'">
							<v-container grid-list-md text-xs-center>
									<v-layout row wrap>
										<v-flex xs6>
											<v-card dark color="secondary">
												<v-card-title><h4>stream</h4></v-card-title>
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
		blockChains: [],
		newMynode: '',
		myNode: [],
		connectedNodes: [],
		addresses: [],
		listPermissions: [],
		loadedBlockchains: false,
		loadedMynode: false,
		loadedConnectedNodes: false,
		loadedAddresses: false,
		loadedListPermissions: false,
		tabName: 'node',
		blockChain: ''
	},
	mutations: {
		loadedBlockchains (state, blockChains) {
			state.blockChains = blockChains
		},
		loadGetInfo (state, myNode) {
			state.myNode = myNode
		},
		loadedMynode (state, loadedMynode) {
			state.loadedMynode = loadedMynode
		},
		loadedConnectedNodes (state, loadedConnectedNodes) {
			state.loadedConnectedNodes = loadedConnectedNodes
		},
		loadConnectedNodes (state, connectedNodes) {
			state.connectedNodes = connectedNodes
		},
		loadedAddresses (state, loadedAddresses) {
			state.loadedAddresses = loadedAddresses
		},
		loadAddresses (state, addresses) {
			state.addresses = addresses
		},
		setTabName (state, tabName) {
			state.tabName = tabName
		},
		setBlockChain (state, blockChain) {
			state.blockChain = blockChain
		},
		loadListPermissions (state, listPermissions) {
			state.listPermissions = listPermissions
		},
		loadedListPermissions (state, loadedListPermissions) {
			state.loadedListPermissions = loadedListPermissions
		},
		clearGetInfo (state) {
			state.newMynode = ''
		}
	},
	actions: {
		loadBlockchains (context) {
			if (context.state.loadedBlockchains == false) {
				axios.get('/v1/api/multichain/blockchains')
					.then(res => {
						console.log(res.data.blockchains)
						context.commit('loadedBlockchains', res.data.blockchains)
					})
					.catch(function (error) {
						console.log(error)
					})
			}
		},
		loadGetInfo (context, blockChain) {
			if (context.state.loadedMynode == false) {
				if (blockChain) {
					axios.get('/v1/api/multichain/getinfo/' + blockChain)
						.then(res => {
							const getInfo = {
								'Chain Name': res.data.result.chainname,
								Description: res.data.result.description,
								'Node Address': res.data.result.nodeaddress,
								'Node Version': res.data.result.nodeversion,
								'Protocol Version': res.data.result.protocolversion,
								'Number of Blocks': res.data.result.blocks,
								'Number of Peers': res.data.result.connections
							}
							context.commit('loadGetInfo',getInfo)
							context.commit('loadedMynode', true)
						})
						.catch(function (error) {
								console.log(error);
						})
				} else {
						context.commit('loadedMynode', false)
				}
			}
			if (context.state.loadedConnectedNodes == false) {
				if (blockChain) {
					axios.get('/v1/api/multichain/getpeerinfo/' + blockChain)
						.then(res => {
							const data = res.data.result
							const nodes = []
							for (let item in data) {
								const node = []
								node.Address = data[item].addr
								node.Latency = data[item].pingtime
								node.Blocks = data[item].synced_blocks
								nodes.push(node)
							}	
							context.commit('loadedConnectedNodes', true)
							context.commit('loadConnectedNodes', nodes)
						})
						.catch(function (error) {
								console.log(error);
						})
				} else {
						context.commit('loadedConnectedNodes', false)
				}
			}
			if (context.state.loadedAddresses == false) {
				if (blockChain) {
					axios.get('/v1/api/multichain/getaddresses/' + blockChain)
						.then(res => {
							const data = res.data.result
							const addresses = []
							const address = {}
							address.Address = data[0]
							context.commit('loadedAddresses', true)
							context.commit('loadAddresses', address)
						})
						.catch(function (error) {
								console.log(error);
						})
				} else {
						context.commit('loadedAddresses', false)
				}
			}
		},
		loadListPermissions (context, blockChain) {
			if (context.state.loadedListPermissions == false) {
				console.log("loadListPermissions")
				if (blockChain) {
					axios.get('/v1/api/multichain/listpermissions/' + blockChain)
						.then(res => {
							const data = res.data.result
							console.log("Load ListPermissions")
							console.log(data)
							const permissions = []
							const array = []
							for (let item in data) {
								const object = {}
								object.address = data[item].address
//								console.log("Data Set")
//								console.log(data[item].type)
								array.push(data[item].type)
							}
							permissions.push(object)
							console.log(permissions)
							context.commit('loadedListPermissions', true)
							context.commit('loadListPermissions', permissions)
						})
						.catch(function (error) {
								console.log(error);
						})
				} else {
						context.commit('loadedListPermissions', false)
				}
			}
		},
		loadConnectedNodes (context, connectedNodes) {
			console.log("loadConnectedNodes")
		},
		clearGetInfo ({ commit }) {
			commit(clearGetInfo)
		}
	},
	getters: {
		loadedBlockchains (state) {
			return state.loadedBlockchains
		}, 
		loadBlockchains (state) {
			console.log("Getters loadBlockchains")
			return state.blockChains
		},
		loadGetInfo (state) {
			return state.myNode
		},
		loadConnectedNodes (state) {
			return state.connectedNodes
		},
		loadAddresses (state) {
			return state.addresses
		},
		tabName (state) {
			return state.tabName
		},
		loadListPermissions (state) {
			return state.listPermissions
		},
		loadedListPermissions (state) {
			return state.loadedListPermissions
		},
		blockChains (state) {
			return state.blockChain
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
			blockChain: '',
			active: '',
			value: '',
			tab: null,
			currentChain: '',
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
//			return this.$store.getters.newMynode
		},
		mynode () {
			return this.$store.getters.loadGetInfo
		},
		connectedNodes () {
			return this.$store.getters.loadConnectedNodes
		},
		addresses () {
			return this.$store.getters.loadAddresses
		},
		tabName () {
			return this.$store.getters.tabName
		},
		items () {
			console.log("Load Blockchains into Items")
			return this.$store.getters.loadBlockchains
		},
		loadedMynode () {
//			return this.$store.getters.loadedMynode
		},
		listPermissions () {
			return this.$store.getters.loadListPermissions
		},
		selectedBlockchain () {
			return this.$store.getters.selectedBlockchain
		}
	},
	methods: {
		loadData (tab) {
			console.log("Tab Blockchain ID : " + this.blockChain)
			console.log("Tab Name : " +tab)
			if (tab == 0) {
				this.$store.commit('setTabName', "node")
			}
			if (tab == 1) {
				this.$store.commit('setTabName', "permissions")
				this.$store.dispatch('loadListPermissions',this.blockChain)
			}
			if (tab == 2) {
				this.$store.commit('setTabName', "stream")
//				this.$store.dispatch('loadGetInfo',this.blockChain)
			}
		},
		changedBlockchain (value) {
			this.$store.commit('setBlockChain', value)
			this.$store.commit('loadedMynode', false)
			this.$store.commit('loadedConnectedNodes', false)
			this.$store.commit('loadedAddresses', false)
			this.$store.commit('loadedListPermissions', false)
			
			this.$store.dispatch('loadGetInfo', value)
		}
	},
	created: function () {
		console.log("onCreate")
		this.$store.dispatch('loadBlockchains')
	}	
}
</script>
