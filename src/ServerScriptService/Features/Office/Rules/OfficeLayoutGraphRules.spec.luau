local Graph = require(script.Parent.OfficeLayoutGraphRules)
return function()
	describe("randomized cardinal office graph", function()
		it("connects occupied cells with controlled extra edges and no duplicate/cardinal degree overflow", function()
			local occupancy, connections, fourPorts = {}, {}, false
			for seed = 1, 100 do
				-- Give Studio a scheduler slice without reducing seed coverage.
				if seed % 5 == 0 then
					task.wait()
				end
				local graph = Graph.generate(Random.new(seed))
				expect(#graph.nodes >= 16 and #graph.nodes <= 24).to.equal(true)
				expect(#graph.edges >= #graph.nodes).to.equal(true)
				local reached, degree, seen = { [1] = true }, {}, {}
				local cells, links = {}, {}
				for _, node in graph.nodes do
					table.insert(cells, node.col .. ":" .. node.row)
				end
				table.sort(cells)
				occupancy[table.concat(cells, ";")] = true
				for _ = 1, #graph.nodes do
					for _, edge in graph.edges do
						if reached[edge.a] or reached[edge.b] then
							reached[edge.a], reached[edge.b] = true, true
						end
					end
				end
				for _, edge in graph.edges do
					local a, b = graph.nodes[edge.a], graph.nodes[edge.b]
					expect(math.abs(a.col - b.col) + math.abs(a.row - b.row)).to.equal(1)
					local key = edge.a .. ":" .. edge.b
					expect(seen[key]).to.equal(nil)
					seen[key] = true
					table.insert(links, key)
					degree[edge.a] = (degree[edge.a] or 0) + 1
					degree[edge.b] = (degree[edge.b] or 0) + 1
				end
				for index in graph.nodes do
					expect(reached[index]).to.equal(true)
					expect(degree[index] <= 4).to.equal(true)
					fourPorts = fourPorts or degree[index] == 4
				end
				table.sort(links)
				connections[table.concat(links, ";")] = true
			end
			local n, m = 0, 0
			for _ in occupancy do
				n += 1
			end
			for _ in connections do
				m += 1
			end
			expect(n >= 50 and m >= 50 and fourPorts).to.equal(true)
		end)
	end)
end
