package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"strings"
	"time"
)

func logger(content string) {

	fmt.Printf("Error: %s\n", content)

}
func falconPost(data string, agent string) (httpcode int, httpresp string, err error) {

	api_url := fmt.Sprintf("http://%s:1988/v1/push", agent)
	post_data := fmt.Sprintf("[%s]", data)

	resp, err := http.Post(api_url, "application/x-www-form-urlencoded", strings.NewReader(post_data))

	if err != nil {
		fmt.Printf("Error:\n%s\n", err)
		return
	}

	defer resp.Body.Close()

	body, err := ioutil.ReadAll(resp.Body)
	fmt.Println(string(body))

	return
}
func main() {

	time_stamp := time.Now().Unix()
	default_endpoint, _ := os.Hostname()
	help_info := "\tdvd-falconpost v1.0\n\tA simple tool for ops to post monitor data to falcon agent.\n\n\tArguments:\n\t\t--help\tPrint Help ( this message ) and exit\n\t\t--data\tShow data ( json format)\n\t\t-m\tMetric ( required )\n\t\t-v\tValue ( required )\n\t\t-c\tCountertype ( default:GAUGE )\n\t\t-s\tStep ( default : 60 (s) )\n\t\t-e\tEndpoint ( default : $HOSTNAME )\n\t\t-t\tTags ( default : Null )\n\t\t-a\tAgentip ( default : 127.0.0.1 )\n\n\tUsage:\n\t\tdvd-falconpost -m Metric -v Value -c Countertype -s Step \\\n\t\t\t\t-e Endpoint -t \"Tags\""

	endpoint := flag.String("e", default_endpoint, "endpoint")
	metric := flag.String("m", "", "metric")
	countertype := flag.String("c", "GAUGE", "counter type")
	step := flag.Int("s", 60, "step")
	tags := flag.String("t", "", "tags")
	value := flag.Float64("v", -0.000000001, "value")
	agent := flag.String("a", "127.0.0.1", "agent http url")
	data_mode := flag.Bool("data", false, "show data in json")
	help_mode := flag.Bool("help", false, "show help info")

	flag.Parse()
	if *help_mode {
		fmt.Println(help_info)
		return
	}

	if *metric == "" {
		logger("Arg metric should not be empty")
		return
	}
	if *value == -0.000000001 {
		logger("Arg value should not be empty")
		return
	}

	data := fmt.Sprintf("{\"metric\":\"%s\",\"endpoint\":\"%s\",\"timestamp\":%d,\"step\":%d,\"value\":%f,\"counterType\":\"%s\",\"tags\":\"%s\"}", *metric, *endpoint, time_stamp, *step, *value, *countertype, *tags)

	if *data_mode {
		fmt.Println(data)
		return
	}
	falconPost(data, *agent)
	return
}
