require 'rubygems'
require 'bundler/setup'

require 'json'
require 'rest-client'


HOST = 'http://job-queue-dev.elasticbeanstalk.com'

class Game

	def initialize
		game_json = RestClient.post("#{HOST}/games", {}).body
		@game = JSON.parse(game_json)
		@machines = [Machine.new(@game['id'])]
	end

	def next_turn
		turn_json = RestClient.get("#{HOST}/games/#{@game['id']}/next_turn").body
		@current_turn = JSON.parse(turn_json)
		@status = @current_turn['status']
		@jobs = @current_turn['jobs']
		@machines.each { |m|  m.play_turn }
	end


	# sorts jobs according to their memory required, descending
	def sort_jobs
		@jobs.sort{|x,y| y['memory_required'] <=> x['memory_required']}
	end


	# sort machines by remaining memory ascending so that largest memory job is assigned to the machine most closely suited for it
	def machines
		@machines.sort{|x,y| x.remaining_memory <=> y.remaining_memory}
	end

	def most_free_machine
		@machines.sort{|x,y| y.remaining_memory <=> x.remaining_memory}.first
	end

	def play
		next_turn
		while (@current_turn['status'] != 'completed')
			job_list = sort_jobs

			job_list.each do |job|
				# first checks if any machine can take job, then assigns the machine with the minimal mem requirement to the job
				if most_free_machine.remaining_memory > job['memory_required']
					machines.each do |m|
						if m.remaining_memory > job['memory_required']
							m.assign(job)
							break
						end
					end
				else
					new_machine = Machine.new(@game['id'])
					new_machine.assign(job)
					@machines.push(new_machine)
				end	
			end
			output_info
			next_turn
		end
	end

	def output_info
		puts "On turn #{@current_turn['current_turn']}, got #{@current_turn['jobs'].count} jobs, having completed #{@current_turn['jobs_completed']} of #{@current_turn['jobs'].count} with #{@current_turn['jobs_running']} jobs running, #{@current_turn['jobs_queued']} jobs queued, and #{@current_turn['machines_running']} machines running"
	end


end

class Machine

	attr_reader :remaining_memory

	def initialize(game_id)
		@game_id = game_id
		machine_json = RestClient.post("#{HOST}/games/#{game_id}/machines", {}).body
		@machine = JSON.parse(machine_json)
		@remaining_memory = 64
		@jobs = {}
	end

	def terminate
		RestClient.delete("#{HOST}/games/#{@game_id}/machines/#{@machine['id']}")
	end

	def assign(job)
		RestClient.post("#{HOST}/games/#{@game_id}/machines/#{@machine['id']}/job_assignments", job_ids: JSON.dump([job['id']])).body
		@remaining_memory -= job['memory_required']
		@jobs[job['id']] = job['turns_required']
	end

	def play_turn
		@jobs.each do |k,v|
			v -= 1
			if v == 0
				self.terminate
			end
		end
	end

end

a = Game.new
a.play