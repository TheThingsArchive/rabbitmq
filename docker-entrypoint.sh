#!/bin/bash
set -e

# If long & short hostnames are not the same, use long hostnames
if [ $(hostname) != $(hostname -s) ]; then
	export RABBITMQ_USE_LONGNAME=true
fi

if [ ${RABBITMQ_SSL_CERT_FILE:+x} -a ${RABBITMQ_SSL_KEY_FILE:+x} -a ${RABBITMQ_SSL_CA_FILE:+x} ]; then
	use_ssl="yes"
fi

if [ "$RABBITMQ_ERLANG_COOKIE" ]; then
	cookieFile='/var/lib/rabbitmq/.erlang.cookie'
	if [ -e "$cookieFile" ]; then
		if [ "$(cat "$cookieFile" 2>/dev/null)" != "$RABBITMQ_ERLANG_COOKIE" ]; then
			echo >&2
			echo >&2 "warning: $cookieFile contents do not match RABBITMQ_ERLANG_COOKIE"
			echo >&2
		fi
	else
		echo "$RABBITMQ_ERLANG_COOKIE" > "$cookieFile"
		chmod 600 "$cookieFile"
		chown rabbitmq "$cookieFile"
	fi
fi

if [ "$1" = 'rabbitmq-server' ]; then
	configs=(
		default_vhost
		default_user
		default_pass
	)

	for conf in "${configs[@]}"; do
		var="RABBITMQ_${conf^^}"
		val="${!var}"
		if [ "$val" ]; then
			break
		fi
	done

	mqttConfigs=(
		vhost
		exchange
		default_user
		default_pass
	)

	for conf in "${mqttConfigs[@]}"; do
		var="RABBITMQ_MQTT_${conf^^}"
		val="${!var}"
		if [ "$val" ]; then
			break
		fi
	done

	cat > /etc/rabbitmq/rabbitmq.config <<-EOH
		[
			{rabbit,
			[
				{ tcp_listeners, [ 5672 ] },
	EOH

	if [ "${use_ssl}" = "yes" ]; then
		cat >> /etc/rabbitmq/rabbitmq.config <<-EOS
				{ ssl_listeners, [ 5671 ] },
				{ ssl_options,  [
				{ certfile,   "$RABBITMQ_SSL_CERT_FILE" },
				{ keyfile,    "$RABBITMQ_SSL_KEY_FILE" },
				{ cacertfile, "$RABBITMQ_SSL_CA_FILE" },
				{ verify,     verify_peer },
				{ fail_if_no_peer_cert, false } ] },
		EOS
	else
		cat >> /etc/rabbitmq/rabbitmq.config <<-EOS
				{ ssl_listeners, [ ] },
		EOS
	fi

	for conf in "${configs[@]}"; do
		var="RABBITMQ_${conf^^}"
		val="${!var}"
		[ "$val" ] || continue
		cat >> /etc/rabbitmq/rabbitmq.config <<-EOC
				{$conf, <<"$val">>},
		EOC
	done
	cat >> /etc/rabbitmq/rabbitmq.config <<-EOF
				{loopback_users, []}
	EOF

	# If management plugin is installed, then generate config consider this
	if [ "$(rabbitmq-plugins list -m -e rabbitmq_management)" ]; then
		cat >> /etc/rabbitmq/rabbitmq.config <<-EOF
				] },
				{ rabbitmq_management, [
					{ listener, [
		EOF

		if [ "${use_ssl}" = "yes" ]; then
			cat >> /etc/rabbitmq/rabbitmq.config <<-EOS
					{ port, 15671 },
					{ ssl, true },
					{ ssl_opts, [
						{ certfile,   "$RABBITMQ_SSL_CERT_FILE" },
						{ keyfile,    "$RABBITMQ_SSL_KEY_FILE" },
						{ cacertfile, "$RABBITMQ_SSL_CA_FILE" },
						{ verify,   verify_peer },
						{ fail_if_no_peer_cert, false }
					] }
				] }
			EOS
		else
			cat >> /etc/rabbitmq/rabbitmq.config <<-EOS
					{ port, 15672 },
					{ ssl, false }
				] }
			EOS
		fi
	fi

	# If mqtt plugin is installed, then generate config consider this
	if [ "$(rabbitmq-plugins list -m -e rabbitmq_mqtt)" ]; then
		cat >> /etc/rabbitmq/rabbitmq.config <<-EOF
				] },
				{ rabbitmq_mqtt, [
					{ allow_anonymous,  true},
					{ subscription_ttl, 1800000},
					{ prefetch,         10},
					{ tcp_listeners,    [1883]},
					{ tcp_listen_options, [ { backlog, 128},
											{ nodelay, true}
										]
					},
		EOF

		for conf in "${mqttConfigs[@]}"; do
			var="RABBITMQ_MQTT_${conf^^}"
			val="${!var}"
			[ "$val" ] || continue
			cat >> /etc/rabbitmq/rabbitmq.config <<-EOC
				{$conf, <<"$val">>},
			EOC
		done

		if [ "${use_ssl}" = "yes" ]; then
			cat >> /etc/rabbitmq/rabbitmq.config <<-EOS
					{ ssl_listeners,    [8883]}
			EOS
		else
			cat >> /etc/rabbitmq/rabbitmq.config <<-EOS
					{ ssl_listeners,    []}
			EOS
		fi
	fi

	cat >> /etc/rabbitmq/rabbitmq.config <<-EOF
			]	}
		].
	EOF

	if [ "${use_ssl}" = "yes" ]; then
		# Create combined cert
		cat ${RABBITMQ_SSL_CERT_FILE} ${RABBITMQ_SSL_KEY_FILE} > /tmp/combined.pem
		chmod 0400 /tmp/combined.pem

		# More ENV vars for make clustering happiness
		# we don't handle clustering in this script, but these args should ensure
		# clustered SSL-enabled members will talk nicely
		export ERL_SSL_PATH=`erl -eval 'io:format("~p", [code:lib_dir(ssl, ebin)]),halt().' -noshell`
		export RABBITMQ_SERVER_ADDITIONAL_ERL_ARGS="-pa ${ERL_SSL_PATH} -proto_dist inet_tls -ssl_dist_opt server_certfile /tmp/combined.pem -ssl_dist_opt server_secure_renegotiate true client_secure_renegotiate true"
		export RABBITMQ_CTL_ERL_ARGS="-pa ${ERL_SSL_PATH} -proto_dist inet_tls -ssl_dist_opt server_certfile /tmp/combined.pem -ssl_dist_opt server_secure_renegotiate true client_secure_renegotiate true"

		echo "Launching RabbitMQ with SSL..."
		echo -e " - RABBITMQ_SSL_CERT_FILE: $RABBITMQ_SSL_CERT_FILE\n - RABBITMQ_SSL_KEY_FILE: $RABBITMQ_SSL_KEY_FILE\n - RABBITMQ_SSL_CA_FILE: $RABBITMQ_SSL_CA_FILE"
	else
		echo "Launching RabbitMQ..."
	fi

	chown -R rabbitmq /var/lib/rabbitmq
	set -- gosu rabbitmq "$@"
fi

exec "$@"
0
