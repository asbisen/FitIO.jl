using Test
using FitIO: base_type, get_base_type_size, get_base_type_data_type, is_valid_base_type
using FitIO: get_base_type_code, get_base_type_invalid_value, get_base_type_id

@testset "Base Type                      " begin
    # Test base type retrieval by id
    @test base_type(0x00).type_name == :enum
    @test base_type(0x01).type_name == :sint8
    @test base_type(0x02).type_name == :uint8

    # Test base type retrieval by name
    @test base_type(:enum).id == 0x00
    @test base_type(:sint8).id == 0x01
    @test base_type(:uint8).id == 0x02

    # Test invalid id throws error
    @test_throws ArgumentError base_type(0xFF)

    # Test invalid name throws error
    @test_throws ArgumentError base_type(:invalid_name)

    # Test property accessors
    @test get_base_type_size(0x00) == 1
    @test get_base_type_data_type(0x01) == Int8
    @test get_base_type_code(0x02) == "B"
    @test get_base_type_invalid_value(0x02) == 0xFF

    # Test validation function
    @test is_valid_base_type(0x02)
    @test is_valid_base_type(:string)
end

