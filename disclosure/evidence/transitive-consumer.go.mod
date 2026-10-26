module example.test/transitive-consumer

go 1.27

require example.test/wrapper v0.0.0

replace example.test/wrapper => ../wrapper
