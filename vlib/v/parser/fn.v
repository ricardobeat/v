// Copyright (c) 2019 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module parser

import (
	v.scanner
	v.ast
	v.token
	v.table
	v.types
	term
	os
)

pub fn (p mut Parser) call_expr() (ast.CallExpr,types.TypeIdent) {
	// println('got fn call')
	tok := p.tok
	fn_name := p.check_name()
	p.check(.lpar)
	mut is_unknown := false
	mut args := []ast.Expr
	mut return_ti := types.new_base_ti(._void, 0)
	if f := p.table.find_fn(fn_name) {
		return_ti = f.return_ti
		for i, arg in f.args {
			e,ti := p.expr(0)
			if !types.check(arg.ti, ti) {
				p.error('cannot use type `$ti.type_name` as type `$arg.ti.type_name` in argument to `$fn_name`')
			}
			args << e
			if i < f.args.len - 1 {
				p.check(.comma)
			}
		}
		if p.tok.kind == .comma {
			p.error('too many arguments in call to `$fn_name`')
		}
	}else{
		is_unknown = true
		p.warn('unknown function `$fn_name`')
		for p.tok.kind != .rpar {
			e,_ := p.expr(0)
			args << e
			if p.tok.kind != .rpar {
				p.check(.comma)
			}
		}
	}
	p.check(.rpar)
	node := ast.CallExpr{
		name: fn_name
		args: args
		is_unknown: is_unknown
		tok: tok
		// typ: return_type
		
	}
	if is_unknown {
		p.table.unknown_calls << node
	}
	return node,return_ti
}

fn (p mut Parser) fn_decl() ast.FnDecl {
	is_pub := p.tok.kind == .key_pub
	if is_pub {
		p.next()
	}
	p.table.clear_vars()
	p.check(.key_fn)
	// Receiver?
	mut rec_name := ''
	mut rec_ti := types.new_base_ti(._void, 0)
	if p.tok.kind == .lpar {
		p.next()
		rec_name = p.check_name()
		if p.tok.kind == .key_mut {
			p.next()
		}
		rec_ti = p.parse_ti()
		p.table.register_var(table.Var{
			name: rec_name
			ti: rec_ti
		})
		p.check(.rpar)
	}
	name := p.check_name()
	// println('fn decl $name')
	p.check(.lpar)
	// Args
	mut args := []table.Var
	mut ast_args := []ast.Arg
	for p.tok.kind != .rpar {
		mut arg_names := [p.check_name()]
		// `a, b, c int`
		for p.tok.kind == .comma {
			p.check(.comma)
			arg_names << p.check_name()
		}
		ti := p.parse_ti()
		for arg_name in arg_names {
			arg := table.Var{
				name: arg_name
				ti: ti
			}
			args << arg
			p.table.register_var(arg)
			ast_args << ast.Arg{
				ti: ti
				name: arg_name
			}
		}
		if p.tok.kind != .rpar {
			p.check(.comma)
		}
	}
	p.check(.rpar)
	// Return type
	mut ti := types.new_base_ti(._void, 0)
	if p.tok.kind in [.amp, .name] {
		ti = p.parse_ti()
		p.return_ti = ti
	}
	p.table.register_fn(table.Fn{
		name: name
		args: args
		return_ti: ti
	})
	stmts := p.parse_block()
	return ast.FnDecl{
		name: name
		stmts: stmts
		ti: ti
		args: ast_args
		is_pub: is_pub
		receiver: ast.Field{
			name: rec_name
			ti: rec_ti
		}
	}
}

pub fn (p &Parser) check_fn_calls() {
	println('check fn calls2')
	for call in p.table.unknown_calls {
		f := p.table.find_fn(call.name) or {
			p.error_at_line('unknown function `$call.name`', call.tok.line_nr)
			return
		}
		println(f.name)
		// println(f.return_type.name)
		// println('IN AST typ=' + call.typ.name)
	}
}
