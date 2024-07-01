import os
import json
import datetime
import glob
import subprocess
from loguru import logger
from dingtalkchatbot.chatbot import DingtalkChatbot


def notify_dingding(dingding_robot_token, title, msg):
    if not dingding_robot_token:
        raise Exception("Dingding robot token not found")
    webhook = f"https://oapi.dingtalk.com/robot/send?access_token={dingding_robot_token}"
    dc = DingtalkChatbot(webhook)
    logger.info(dc.send_markdown(title=title, text=msg))


def check_topio_status():
    try:
        # 执行命令并获取输出
        result = subprocess.run('ps -ef | grep topio | grep -v grep', shell=True, stdout=subprocess.PIPE,
                                universal_newlines=True)

        # 检查命令是否执行成功
        if result.returncode != 0:
            raise Exception("Failed to execute ps command")

        # 获取命令输出
        output = result.stdout

        # 检查是否存在 xnode process 和 daemon process
        xnode_process_found = False
        daemon_process_found = False

        for line in output.splitlines():
            if "topio: xnode process" in line:
                xnode_process_found = True
            if "topio: daemon process" in line:
                daemon_process_found = True

        # 判断topio是否正常运行
        if not xnode_process_found or not daemon_process_found:
            logger.error("topio 程序异常：xnode process 或 daemon process 进程缺失")
            exit(1)
        else:
            logger.info("topio 程序正常运行")

    except Exception as e:
        logger.error(f"发生异常：{e}")
        exit(1)


def check_topio_network_status():
    try:
        # 执行命令并获取输出
        result = subprocess.run(['/chain/topio', 'node', 'isjoined'], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                universal_newlines=True)

        # 检查命令是否执行成功
        if result.returncode != 0:
            logger.error(f"Failed to execute command: {result.stderr}")

        # 获取命令输出
        output = result.stdout.strip()

        # 判断topio是否入网
        if output == "YES":
            logger.info("node is joined")
        else:
            logger.warning("node is not joined")

    except Exception as e:
        logger.error(f"发生异常：{e}")


def check_sync_status(account):
    try:
        # 执行命令并获取输出
        result = subprocess.run(['/chain/topio', 'chain', 'syncstatus'], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                universal_newlines=True)

        # 检查命令是否执行成功
        if result.returncode != 0:
            logger.error(f"Failed to execute command: {result.stderr}")

        # 获取命令输出
        output = result.stdout.strip()

        # 解析输出，获取各个 sync-mode 的 total 值
        sync_status = {}
        for line in output.splitlines():
            if 'total' in line:
                parts = line.split(',')
                sync_mode = parts[0].strip()
                total_str = parts[1].split(':')[1].strip().replace('%', '')
                total_value = float(total_str)
                sync_status[sync_mode] = total_value

        # 输出 sync_status 字典
        print(sync_status)

        # 判断是否所有 mode 的 total 值都是 100
        all_synced = all(value == 100.00 for value in sync_status.values())

        if all_synced:
            logger.info("所有节点已完成同步")
        else:
            title = "节点同步状态落后告警"
            message = f"""
            **节点地址：** {account}
            **同步状态：** {sync_status}
            """
            logger.warning(title + '\n' + message)
            notify_dingding(os.environ.get('DINGDING_ROBOT_TOKEN'), title, message)
    except Exception as e:
        logger.error(f"发生异常：{e}")


def check_core_files(account):
    try:
        # 执行命令并获取输出
        result = subprocess.run(['ls', '-l', '/chain'], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                universal_newlines=True)

        # 检查命令是否执行成功
        if result.returncode != 0:
            logger.error(f"Failed to execute command: {result.stderr}")

        # 获取命令输出
        output = result.stdout.strip()

        # 过滤出包含 "core" 的行
        core_files = [line for line in output.splitlines() if 'core' in line]

        if not core_files:
            logger.info("没有core文件")
        else:
            # 获取 core 文件的数量
            core_count = len(core_files)

            # 提取文件日期，假设文件日期在第6、7、8列
            dates = []
            for line in core_files:
                parts = line.split()
                # 假设日期在第6、7、8列，例如 "Jun 26 08:54"
                date_str = f"{parts[5]} {parts[6]} {parts[7]}"
                dates.append(date_str)

            # 将日期转换为时间戳排序
            dates = [subprocess.run(['date', '-d', date_str, '+%s'], stdout=subprocess.PIPE,
                                    universal_newlines=True).stdout.strip()
                     for date_str in dates]
            dates.sort()

            # 获取最老和最新的日期
            oldest_date = subprocess.run(['date', '-d', f"@{dates[0]}", '+%Y-%m-%d %H:%M:%S'], stdout=subprocess.PIPE,
                                         universal_newlines=True).stdout.strip()
            newest_date = subprocess.run(['date', '-d', f"@{dates[-1]}", '+%Y-%m-%d %H:%M:%S'], stdout=subprocess.PIPE,
                                         universal_newlines=True).stdout.strip()

            title = "节点core文件告警"
            if core_count == 1:
                logger.warning(f"有1个core文件，core文件日期：{newest_date}")

                message = f"""
                        **节点地址：** {account}
                        **core文件信息：** 有1个core文件，core文件日期：{newest_date}
                        """

            else:
                logger.warning(
                    f"有{core_count}个core文件，最老core文件日期：{oldest_date}，最新core文件日期：{newest_date}")
                message = f"""
                        **节点地址：** {account}
                        **core文件信息：** 有{core_count}个core文件，最老core文件日期：{oldest_date}，最新core文件日期：{newest_date}
                        """

            notify_dingding(os.environ.get('DINGDING_ROBOT_TOKEN'), title, message)
    except Exception as e:
        logger.error(f"发生异常：{e}")


def check_error_logs(account):
    try:
        # 使用 glob 获取匹配的日志文件
        log_files = glob.glob('/chain/log/xtop*log')

        if not log_files:
            logger.warning("没有找到匹配的日志文件")
            return

        # 构建 grep 命令
        grep_command = ['grep', '-a', 'Error'] + log_files

        # 执行命令并获取输出
        result = subprocess.run(grep_command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)

        # 检查命令是否执行成功
        if result.returncode == 1:
            # grep 命令返回 1 表示未找到匹配
            logger.info("没有Error日志")
        elif result.returncode != 0:
            # 其他返回码表示命令执行出错
            logger.error(f"Failed to execute command: {result.stderr}")
        else:
            # 获取命令输出
            output = result.stdout.strip()

            if not output:
                logger.info("没有Error日志")
            else:
                logger.warning(f"Error日志如下：{output}")

                title = "节点Error日志告警"
                message = f"""
                            **节点地址：** {account}
                            **Error日志信息：** {output}
                            """
                logger.warning(title + '\n' + message)
                notify_dingding(os.environ.get('DINGDING_ROBOT_TOKEN'), title, message)

    except Exception as e:
        logger.error(f"发生异常：{e}")


def get_account_addr():
    try:
        with open("/chain/keystore/config.json", "r") as f:
            config = json.load(f)

        return config["account address"]
    except FileNotFoundError:
        logger.error("config.json文件未找到")
    except Exception as e:
        logger.error(f"发生异常：{e}")


def main():
    account = get_account_addr()
    # 执行任务A
    check_topio_status()

    # 获取当前时间
    now = datetime.datetime.now()

    # 获取当前时间的小时、分钟和秒
    current_hour = now.hour
    current_minute = now.minute
    current_second = now.second

    # 检查任务B是否应该执行（每小时执行一次）
    # 在每小时的第一个分钟的第一个5秒内触发
    if current_minute == 0 and current_second < 5:
        check_sync_status(account)
        check_core_files(account)
        check_error_logs(account)

    # 检查任务C是否应该执行（每天执行一次）
    # 在每天的第一个分钟的第一个5秒内触发
    # if current_hour == 0 and current_minute == 0 and current_second < 5:
    #     pass


if __name__ == '__main__':
    main()
