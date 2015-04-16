require 'rubygems'
require 'bundler/setup'

require 'json'
require 'rest-client'


def start_game
	host = 'http://job-queue-dev.elasticbeanstalk.com'

	game_json = RestClient.post("#{host}/games", {}).body
	
	game = JSON.parse(game_json)
end

	HOST = 'http://job-queue-dev.elasticbeanstalk.com'
class Game


	def initialize
		game_json = RestClient.post("#{HOST}/games", {}).body
		@game = JSON.parse(game_json)
		@machines = []
	end

	def next_turn
		turn_json = RestClient.get("#{HOST}/games/#{@game['id']}/next_turn").body
		@current_turn = JSON.parse(turn_json)
		@status = @current_turn['status']
		@jobs = @current_turn['jobs']
	end


	# sorts jobs according to their memory required, descending
	def sort_jobs
		@jobs.sort{|x,y| y['memory_required'] <=> x['memory_required']}
	end

	def play_turn
		until @game['completed']
			next_turn
			if @jobs.any?
				job_list = sort_jobs

				job_list.each do |job|
					@machines.each do |machine|
						if machine.remaining_memory >= job['memory_required']
							machine.assign(job['id'])
						end
				end

			end

		end

	end


end

class Machine

	def initialize(game_id)
		@game_id = game_id
		@machine_json = RestClient.post("#{HOST}/games/#{game_id}/machines").body
		@machine = JSON.parse(machine_json)
		@remaining_memory = 64
	end

	def terminate
		RestClient.delete("#{HOST}/games/#{@game_id}/machines/#{@machine['id']}")
	end

	def assign(job_id)
		RestClient.post("#{HOST}/games/#{@game_id}/machines/#{@machine['id']}/job_assignments",
			job_ids: JSON.dump(job_id))
	end

end

a = Game.new
a.next_turn
p a
puts " ----- "
a.next_turn
p a