<template>
    <v-container fluid>
        <v-layout row wrap>
            <v-flex>
                <v-flex xs6>
                    <v-subheader>Standard with focus</v-subheader>
                </v-flex>
                <v-flex xs6>
                    <v-select
                    :blocks="blocks"
                    v-model="e2"
                    label="Select"
                    class="input-group--focused"
                    item-value="text"
                    ></v-select>
                </v-flex>
            </v-flex>
        </v-layout>
        <v-layout row wrap>
				<v-tabs
				color="cyan"
				slot="extension"
				v-model="tab"
				align-with-title
				>
					<v-tabs-slider color="yellow"></v-tabs-slider>
						<v-tab v-for="tab in tabs" :key="tab">
							{{ tab }}
						</v-tab>
					</v-tabs>
				</v-tabs>
        </v-layout>
    </v-container>
</template>

<script>
	export default {
		data () {
			return {
			blocks: [
				{ text: 'State 1' },
				{ text: 'State 2' },
				{ text: 'State 3' },
				{ text: 'State 4' },
				{ text: 'State 5' },
				{ text: 'State 6' },
				{ text: 'State 7' }
			],
			tab: null,
			tabs: [
				'Node','Permissions','View Stream'
			]
			text : 'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.'
		}
	}
</script>
