require 'rubygems'
require 'bundler/setup'
require 'json'
require 'rest-client'


HOST = 'http://job-queue-dev.elasticbeanstalk.com'

class Game

	def initialize
		game_json = RestClient.post("#{HOST}/games", {}).body
		@game = JSON.parse(game_json)
		@machines = []
		@total_jobs = 0
	end

	def next_turn
		turn_json = RestClient.get("#{HOST}/games/#{@game['id']}/next_turn").body
		@current_turn = JSON.parse(turn_json)
		@status = @current_turn['status']
		@jobs = @current_turn['jobs']
		@total_jobs += @current_turn['jobs'].count
		@machines.each { |m|  m.play_turn }
	end


	# sorts jobs according to their memory required, descending
	def sort_jobs
		@jobs.sort{|x,y| y['memory_required'] <=> x['memory_required']}
	end


	# sort machines by remaining memory ascending so that largest memory job is assigned to the machine most closely suited for it
	def sorted_machines
		@machines.sort{|x,y| x.remaining_memory <=> y.remaining_memory}
	end

	def memory_available?(job)
		@machines.sort{|x,y| y.remaining_memory <=> x.remaining_memory}.first.remaining_memory > job['memory_required']
	end

	def play
		next_turn

		while (@status != 'completed')
			# Remove any machines that finished processing all jobs.
			check_machines

			# Sort jobs in descending order in terms of memory required
			job_list = sort_jobs

			job_list.each do |job|
				# Creates machine if there are none.
				if @machines.empty?
					new_machine = Machine.new(@game['id'])
					@machines.push(new_machine)
				end

				# First checks if any machine can take job
				if memory_available?(job)
					# Assigns job to the machine with smallest available memory capable of taking on job
					sorted_machines.each do |m|
						if m.remaining_memory > job['memory_required']
							m.assign(job)
							break
						end
					end
					# Otherwise make a new machine for assignment
				else
					new_machine = Machine.new(@game['id'])
					new_machine.assign(job)
					@machines.push(new_machine)
				end	
			end
			output_info
			next_turn
		end
		output_results
	end

	def output_results 
		game_json = RestClient.get("#{HOST}/games/#{@game['id']}",).body
		puts game_json
		puts "----"
		completed = JSON.parse(game_json)
		puts "Game complete"
		puts "Total delay: #{completed['delay_turns']} turns"
		puts "Total cost: #{completed['cost']}"
	end

	def output_info
		puts "On turn #{@current_turn['current_turn']}, got #{@current_turn['jobs'].count} jobs, having completed #{@current_turn['jobs_completed']} of #{@total_jobs} with #{@current_turn['jobs_running']} jobs running, #{@current_turn['jobs_queued']} jobs queued, and #{@current_turn['machines_running']} machines running"
	end

	def check_machines
		@machines.each do |m|
			@machines.delete(m) if m.machine_empty?
		end
	end

end

class Machine

	attr_reader :remaining_memory

	def initialize(game_id)
		@game_id = game_id
		machine_json = RestClient.post("#{HOST}/games/#{game_id}/machines", {}).body
		@machine = JSON.parse(machine_json)
		@remaining_memory = 64
		@assigned_jobs = {}
	end

	def terminate
		RestClient.delete("#{HOST}/games/#{@game_id}/machines/#{@machine['id']}")
	end

	def assign(job)
		RestClient.post("#{HOST}/games/#{@game_id}/machines/#{@machine['id']}/job_assignments", job_ids: JSON.dump([job['id']])).body
		@remaining_memory -= job['memory_required']
		@assigned_jobs[job] = job['turns_required']
	end

	def play_turn
		@assigned_jobs.each do |job, turns_left|
			@assigned_jobs[job] -= 1
			#if no more turns remaining, remove job and restore memory for reassignment
			if @assigned_jobs[job] == 0
				@remaining_memory += job['memory_required']
				@assigned_jobs.delete(job)
			end
		end
	end

	def machine_empty?
		if @assigned_jobs.values.all?{|v| v == 0}
			self.terminate
			return true
		end

		false
	end

end

a = Game.new
a.play