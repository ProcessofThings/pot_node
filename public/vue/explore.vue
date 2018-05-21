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
												<v-expansion-panel>
													<v-expansion-panel-content v-for="listPermission in listPermissions">
														<div slot="header">Peer : {{ listPermission.address }}</div>
															<v-list dark two-line>
																<v-list-tile-content class="my-3">
																	<v-list-tile-title class="ml-3">Permissions</v-list-tile-title>
																	<v-list-tile-sub-title class="ml-5" v-for="rights in listPermission.permissions">{{rights}}</v-list-tile-sub-title>
																</v-list-tile-content>
															</v-list>
													</v-expansion-panel-content>
												</v-expansion-panel>
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
												<v-card-title><h4>Subscribed Streams</h4></v-card-title>
												<v-divider></v-divider>
												<v-list dark two-line v-for="subs in subscribed">
													<v-list-tile-content class="my-3">
														<v-list-tile-title class="ml-3">Name</v-list-tile-title>
														<v-list-tile-sub-title class="ml-5" v-if="subs.items > 0" v-model="subs.createtxid" @click="loadStream(subs.createtxid)">{{ subs.name }}</v-list-tile-sub-title>
														<v-list-tile-sub-title class="ml-5" v-else="subs.items > 0">{{ subs.name }}</v-list-tile-sub-title>
														<v-list-tile-title class="ml-3">Created By</v-list-tile-title>
														<v-list-tile-sub-title class="ml-5">{{ subs.creators[0] }}</v-list-tile-sub-title>
														<v-list-tile-title class="ml-3">Items</v-list-tile-title>
														<v-list-tile-sub-title class="ml-5">{{ subs.items }}</v-list-tile-sub-title>
														<v-list-tile-title class="ml-3">Publishers</v-list-tile-title>
														<v-list-tile-sub-title class="ml-5">{{ subs.publishers }}</v-list-tile-sub-title>
													</v-list-tile-content>
													<v-divider></v-divider>
												</v-list>
											</v-card>
											<v-card dark color="secondary">
												<v-card-title><h4>Availible Streams</h4></v-card-title>
											</v-card>
										</v-flex>
										<v-flex xs6>
											<v-card dark color="secondary">
												<v-card-title><h4>Streams</h4></v-card-title>
												<v-divider></v-divider>
												<v-list dark two-line v-for="streamItem in streamItems">
													<v-list-tile-content class="my-3">
														<v-list-tile-title class="ml-3">Publisher</v-list-tile-title>
														<v-list-tile-sub-title class="ml-5" v-model="streamItem.streamId" @click="loadStreamPublisherItems({txid: streamItem.streamId, publisher: streamItem.publisher})">{{ streamItem.publisher }}</v-list-tile-sub-title>
														<v-list-tile-title class="ml-3">Key</v-list-tile-title>
														<v-list-tile-sub-title class="ml-5"><a style="color:secondary" v-model="streamItem.streamId" @click="loadStreamKeyItems({txid: streamItem.streamId, key: streamItem.key})">{{ streamItem.key }}</a></v-list-tile-sub-title>
														<v-list-tile-title class="ml-3">Data</v-list-tile-title>
														<v-list-tile-sub-title class="ml-5">{{ streamItem.data }}</v-list-tile-sub-title>
														<v-list-tile-title class="ml-3">Added</v-list-tile-title>
														<v-list-tile-sub-title class="ml-5">{{ streamItem.added }}</v-list-tile-sub-title>
														<v-list-tile-title class="ml-3">Confirmations</v-list-tile-title>
														<v-list-tile-sub-title class="ml-5">{{ streamItem.confirmations }}</v-list-tile-sub-title>
													</v-list-tile-content>
													<v-divider></v-divider>
												</v-list>
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

function hexToAscii(str){
                    hexString = str;
                    strOut = '';
                    for (x = 0; x < hexString.length; x += 2) {
                        strOut += String.fromCharCode(parseInt(hexString.substr(x, 2), 16));
                    }
                    return strOut;    
				};

store.registerModule('explore', { 
	state: {
		blockChains: [],
		newMynode: '',
		myNode: [],
		connectedNodes: [],
		addresses: [],
		listPermissions: [],
		subscribed: [],
		stream: [],
		streamItems: [],
		loadedBlockchains: false,
		loadedMynode: false,
		loadedConnectedNodes: false,
		loadedAddresses: false,
		loadedListPermissions: false,
		loadedSubscribed: false,
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
		loadedSubscribed (state, loadedSubscribed) {
			state.loadedSubscribed = loadedSubscribed
		},
		loadSubscribed (state, subscribed) {
			state.subscribed = subscribed
		},
		loadStreamItems (state, streamItems) {
			state.streamItems = streamItems
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
							console.log(nodes)
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
							var address = ''
							const permissions = []
							const array = []
							for (let item in data) {
								address = data[item].address
//								console.log("Data Set")
//								console.log(data[item].type)
								array.push(data[item].type)
							}
							permissions.push({
								address: address,
								permissions: array
							})
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
		loadSubscribed (context, blockChain) {
			if (context.state.loadedSubscribed == false) {
				console.log("loadSubscribed")
				if (blockChain) {
					axios.get('/v1/api/multichain/liststreams/' + blockChain)
						.then(res => {
							const data = res.data.result
							console.log("Load Subscribed")
							console.log(data)
							context.commit('loadedSubscribed', true)
							context.commit('loadSubscribed', data)
						})
						.catch(function (error) {
								console.log(error);
						})
				} else {
						context.commit('loadedSubscribed', false)
				}
			}
		},
		loadStreamItems (context, payload) {
			axios.get('/v1/api/multichain/liststreamitems/' + payload.blockChain +'?streamId=' + payload.streamId + '&verbose=true&count=100')
			.then(res => {
				const data = res.data.result
				console.log("Load StreamItems")
				console.log(data)
				const streamItems = []

				var options = {
                    //weekday: 'long',
                    month: 'short',
                    year: 'numeric',
                    day: 'numeric',
                    hour: 'numeric',
                    minute: 'numeric',
                    second: 'numeric'
				},intlDate = new Intl.DateTimeFormat( undefined, options );
				 
				for (let item in data) {
					const object = {} 
					object.publisher = data[item].publishers[0]
					object.key = data[item].key
					object.streamId = payload.streamId
					object.txid = data[item].txid
					var hexString = data[item].data
					var strOut = '';
					for (x = 0; x < hexString.length; x += 2) {
						strOut += String.fromCharCode(parseInt(hexString.substr(x, 2), 16));
					}
					recorddata = strOut
					if (recorddata.match(/^Salt/)  || recorddata.match(/^stream/)) {
						recorddata = "Encrypted"
					}
					if (data[item].data == '00') {
						recorddata = "Marked As Deleted"
					}
					object.data = recorddata
					object.added = intlDate.format( new Date( 1000 * data[item].blocktime ) )
					object.confirmations = data[item].confirmations
					streamItems.push(object)
				}
				console.log(streamItems)
				context.commit('loadStreamItems', streamItems)
			})
			.catch(function (error) {
				console.log(error);
			})
		},
		loadStreamPublisherItems (context, payload) {
			axios.get('/v1/api/multichain/liststreampublisheritems/' + payload.blockChain +'?streamId=' + payload.streamId + '&address='+ payload.address +'&verbose=true&count=100')
			.then(res => {
				const data = res.data.result
				console.log("Load StreamPublisherItems")
				console.log(data)
				const streamItems = []

				var options = {
                    //weekday: 'long',
                    month: 'short',
                    year: 'numeric',
                    day: 'numeric',
                    hour: 'numeric',
                    minute: 'numeric',
                    second: 'numeric'
				},intlDate = new Intl.DateTimeFormat( undefined, options );
				 
				for (let item in data) {
					const object = {} 
					object.publisher = data[item].publishers[0]
					object.key = data[item].key
					object.streamId = payload.streamId
					object.txid = data[item].txid
					var hexString = data[item].data
					var strOut = '';
					for (x = 0; x < hexString.length; x += 2) {
						strOut += String.fromCharCode(parseInt(hexString.substr(x, 2), 16));
					}
					recorddata = strOut
					if (recorddata.match(/^Salt/)  || recorddata.match(/^stream/)) {
						recorddata = "Encrypted"
					}
					if (data[item].data == '00') {
						recorddata = "Marked As Deleted"
					}
					object.data = recorddata
					object.added = intlDate.format( new Date( 1000 * data[item].blocktime ) )
					object.confirmations = data[item].confirmations
					streamItems.push(object)
				}
				console.log(streamItems)
				context.commit('loadStreamItems', streamItems)
			})
			.catch(function (error) {
				console.log(error);
			})
		},
		loadStreamKeyItems (context, payload) {
			console.log("KeyItems" + payload)
			axios.get('/v1/api/multichain/liststreamkeyitems/' + payload.blockChain +'?streamId=' + payload.streamId + '&key='+ payload.key +'&verbose=true&count=100')
			.then(res => {
				const data = res.data.result
				console.log("Load StreamPublisherItems")
				console.log(data)
				const streamItems = []

				var options = {
                    //weekday: 'long',
                    month: 'short',
                    year: 'numeric',
                    day: 'numeric',
                    hour: 'numeric',
                    minute: 'numeric',
                    second: 'numeric'
				},intlDate = new Intl.DateTimeFormat( undefined, options );
				 
				for (let item in data) {
					const object = {} 
					object.publisher = data[item].publishers[0]
					object.key = data[item].key
					object.streamId = payload.streamId
					object.txid = data[item].txid
					var hexString = data[item].data
					var strOut = '';
					for (x = 0; x < hexString.length; x += 2) {
						strOut += String.fromCharCode(parseInt(hexString.substr(x, 2), 16));
					}
					recorddata = strOut
					if (recorddata.match(/^Salt/)  || recorddata.match(/^stream/)) {
						recorddata = "Encrypted"
					}
					if (data[item].data == '00') {
						recorddata = "Marked As Deleted"
					}
					object.data = recorddata
					object.added = intlDate.format( new Date( 1000 * data[item].blocktime ) )
					object.confirmations = data[item].confirmations
					streamItems.push(object)
				}
				console.log(streamItems)
				context.commit('loadStreamItems', streamItems)
			})
			.catch(function (error) {
				console.log(error);
			})
		},
		loadConnectedNodes (context, connectedNodes) {
			console.log("loadConnectedNodes")
		},
		loadStream (context, id) {
			console.log(id)
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
		},
		loadedSubscribed (state) {
			return state.loadedSubscribed
		},
		loadSubscribed (state) {
			return state.subscribed
		},
		loadStreamItems (state) {
			return state.streamItems
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
		},
		subscribed () {
			return this.$store.getters.loadSubscribed
		},
		stream () {
				return this.$store.getters.loadStream
		},
		streamItems () {
			return this.$store.getters.loadStreamItems
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
				this.$store.dispatch('loadSubscribed',this.blockChain)
			}
		},
		loadStream (id) {
			this.$store.dispatch('loadStreamItems',{
				blockChain: this.blockChain,
				streamId: id
			})
		},
		loadStreamPublisherItems (payload) {
			this.$store.dispatch('loadStreamPublisherItems',{
				blockChain: this.blockChain,
				streamId: payload.txid,
				address: payload.publisher
			})
		},
		loadStreamKeyItems (payload) {
			this.$store.dispatch('loadStreamKeyItems',{
				blockChain: this.blockChain,
				streamId: payload.txid,
				key: payload.key
			})
		},	
		changedBlockchain (value) {
			this.$store.commit('setBlockChain', value)
			this.$store.commit('loadedMynode', false)
			this.$store.commit('loadedConnectedNodes', false)
			this.$store.commit('loadedAddresses', false)
			this.$store.commit('loadedListPermissions', false)
			this.$store.commit('loadedSubscribed', false)
			this.$store.dispatch('loadGetInfo', value)
		}
	},
	created: function () {
		console.log("onCreate")
		this.$store.dispatch('loadBlockchains')
	}	
}
</script>
