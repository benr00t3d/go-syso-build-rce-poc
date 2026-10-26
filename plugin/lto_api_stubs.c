#include <stdint.h>

/*
 * Xcode 27's linker has direct imports from libLTO. dyld resolves those
 * imports before it runs library constructors. These placeholders satisfy
 * that binding surface; they are deliberately not an LTO implementation.
 * Once initializers have run, returning zero makes the link fail safely.
 */
#define LTO_STUB(name)                                                        \
    __attribute__((used, visibility("default"))) uintptr_t name(void) {      \
        return 0;                                                             \
    }

LTO_STUB(lto_api_version)
LTO_STUB(lto_codegen_add_module)
LTO_STUB(lto_codegen_add_must_preserve_symbol)
LTO_STUB(lto_codegen_compile_optimized)
LTO_STUB(lto_codegen_create_in_local_context)
LTO_STUB(lto_codegen_debug_options_array)
LTO_STUB(lto_codegen_optimize)
LTO_STUB(lto_codegen_set_cpu)
LTO_STUB(lto_codegen_set_diagnostic_handler)
LTO_STUB(lto_codegen_set_pic_model)
LTO_STUB(lto_codegen_set_should_embed_uselists)
LTO_STUB(lto_codegen_write_merged_modules)
LTO_STUB(lto_get_error_message)
LTO_STUB(lto_get_version)
LTO_STUB(lto_module_create_in_codegen_context)
LTO_STUB(lto_module_create_in_local_context)
LTO_STUB(lto_module_dispose)
LTO_STUB(lto_module_get_asm_undef_symbol_name)
LTO_STUB(lto_module_get_num_asm_undef_symbols)
LTO_STUB(lto_module_get_num_symbols)
LTO_STUB(lto_module_get_symbol_attribute)
LTO_STUB(lto_module_get_symbol_name)
LTO_STUB(lto_module_get_target_triple)
LTO_STUB(lto_module_has_objc_category)
LTO_STUB(lto_module_is_thinlto)
LTO_STUB(lto_runtime_lib_symbols_list)
LTO_STUB(thinlto_codegen_add_cross_referenced_symbol)
LTO_STUB(thinlto_codegen_add_module)
LTO_STUB(thinlto_codegen_add_must_preserve_symbol)
LTO_STUB(thinlto_codegen_process)
LTO_STUB(thinlto_codegen_set_cache_dir)
LTO_STUB(thinlto_codegen_set_cache_entry_expiration)
LTO_STUB(thinlto_codegen_set_cache_pruning_interval)
LTO_STUB(thinlto_codegen_set_codegen_only)
LTO_STUB(thinlto_codegen_set_cpu)
LTO_STUB(thinlto_codegen_set_final_cache_size_relative_to_available_space)
LTO_STUB(thinlto_codegen_set_pic_model)
LTO_STUB(thinlto_codegen_set_savetemps_dir)
LTO_STUB(thinlto_create_codegen)
LTO_STUB(thinlto_debug_options)
LTO_STUB(thinlto_module_get_num_object_files)
LTO_STUB(thinlto_module_get_num_objects)
LTO_STUB(thinlto_module_get_object)
LTO_STUB(thinlto_module_get_object_file)
LTO_STUB(thinlto_set_generated_objects_dir)
