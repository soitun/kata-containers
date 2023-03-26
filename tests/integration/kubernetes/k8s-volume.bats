#!/usr/bin/env bats
#
# Copyright (c) 2018 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0
#

load "${BATS_TEST_DIRNAME}/tests_common.sh"
load "${BATS_TEST_DIRNAME}/../../common.bash"
TEST_INITRD="${TEST_INITRD:-no}"

setup() {
	[ "${KATA_HYPERVISOR}" == "firecracker" ] && skip "test not working see: ${fc_limitations}"

	get_pod_config_dir

	tmp_file=$(mktemp -d /tmp/data.XXXX)
	pod_yaml=$(mktemp --tmpdir pod_config.XXXXXX.yaml)
	msg="Hello from Kubernetes"
	echo $msg > $tmp_file/index.html
	pod_name="pv-pod"
	# Define temporary file at yaml
	sed -e "s|tmp_data|${tmp_file}|g" ${pod_config_dir}/pv-volume.yaml > "$pod_yaml"
}

@test "Create Persistent Volume" {
	[ "${KATA_HYPERVISOR}" == "firecracker" ] && skip "test not working see: ${fc_limitations}"

	volume_name="pv-volume"
	volume_claim="pv-claim"

	# Create the persistent volume
	kubectl create -f "$pod_yaml"

	# Check the persistent volume is Available
	cmd="kubectl get pv $volume_name | grep Available"
	waitForProcess "$wait_time" "$sleep_time" "$cmd"

	# Create the persistent volume claim
	kubectl create -f "${pod_config_dir}/volume-claim.yaml"

	# Check the persistent volume claim is Bound.
	cmd="kubectl get pvc $volume_claim | grep Bound"
	waitForProcess "$wait_time" "$sleep_time" "$cmd"

	# Create pod
	kubectl create -f "${pod_config_dir}/pv-pod.yaml"

	# Check pod creation
	kubectl wait --for=condition=Ready --timeout=$timeout pod "$pod_name"

	cmd="cat /mnt/index.html"
	kubectl exec $pod_name -- sh -c "$cmd" | grep "$msg"
}

teardown() {
	[ "${KATA_HYPERVISOR}" == "firecracker" ] && skip "test not working see: ${fc_limitations}"

	# Debugging information
	kubectl describe "pod/$pod_name"

	kubectl delete pod "$pod_name"
	kubectl delete pvc "$volume_claim"
	kubectl delete pv "$volume_name"
	rm -f "$pod_yaml"
	rm -rf "$tmp_file"
}
