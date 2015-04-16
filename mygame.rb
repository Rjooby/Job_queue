require 'rubygems'
require 'bundler/setup'

require 'json'
require 'rest-client'


def start_game
	host = 'http://job-queue-dev.elasticbeanstalk.com'

	game_json = RestClient.post("#{host}/games", {}).body
	
	game = JSON.parse(game_json)
end

class Game

	HOST = 'http://job-queue-dev.elasticbeanstalk.com'

	def initialize
		game_json = RestClient.post("#{HOST}/games", {}).body
		@game = JSON.parse(game_json)
		@game_id = @game['id']
		@status = ''
	end

	def next_turn
		turn_json = RestClient.get("#{HOST}/games/#{@game['id']}/next_turn").body
		turn = JSON.parse(turn_json)
		@status = turn['status']
		@jobs = turn['jobs']
	end

end

class Machine

end

a = Game.new
a.next_turn
p a
