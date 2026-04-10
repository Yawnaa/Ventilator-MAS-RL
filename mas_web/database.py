"""
数据库管理模块
连接PostgreSQL并查询患者实时数据
"""

import psycopg2
from psycopg2.extras import RealDictCursor
import pandas as pd
from datetime import datetime, timedelta
from config import DATABASE_CONFIG
import streamlit as st

@st.cache_resource
def get_db_connection():
    """获取数据库连接（缓存）"""
    try:
        conn = psycopg2.connect(**DATABASE_CONFIG)
        return conn
    except Exception as e:
        st.error(f"数据库连接失败: {e}")
        return None

def query_patient_vitals(subject_id, hadm_id, lookback_minutes=60):
    """
    查询患者实时生理参数
    
    参数:
        subject_id: 患者ID
        hadm_id: 住院ID
        lookback_minutes: 回溯时间（分钟）
    
    返回:
        DataFrame: 包含时间戳和生理参数的数据框
    """
    conn = get_db_connection()
    if not conn:
        return None
    
    query = """
    SELECT charttime, heart_rate, spo2, resp_rate
    FROM getallfluids
    WHERE subject_id = %s AND hadm_id = %s
    AND charttime >= NOW() - INTERVAL '%s minutes'
    ORDER BY charttime DESC
    LIMIT %s
    """
    
    try:
        df = pd.read_sql_query(
            query,
            conn,
            params=(subject_id, hadm_id, lookback_minutes, lookback_minutes)
        )
        return df.sort_values('charttime').reset_index(drop=True)
    except Exception as e:
        st.warning(f"查询失败: {e}")
        return None
    finally:
        if conn:
            conn.close()

def query_ventilator_settings(hadm_id, max_records=10):
    """
    查询呼吸机参数历史
    
    参数:
        hadm_id: 住院ID
        max_records: 最大记录数
    
    返回:
        DataFrame: 参数历史
    """
    conn = get_db_connection()
    if not conn:
        return None
    
    query = """
    SELECT charttime, peep, fio2, tidal_volume, rate_set
    FROM ventilator_settings
    WHERE hadm_id = %s
    ORDER BY charttime DESC
    LIMIT %s
    """
    
    try:
        df = pd.read_sql_query(
            query,
            conn,
            params=(hadm_id, max_records)
        )
        return df.sort_values('charttime').reset_index(drop=True)
    except Exception as e:
        st.warning(f"查询呼吸机参数失败: {e}")
        return None
    finally:
        if conn:
            conn.close()

def get_patient_demographics(subject_id):
    """
    获取患者基本信息
    """
    conn = get_db_connection()
    if not conn:
        return None
    
    query = """
    SELECT subject_id, gender, anchor_year_group, admission_type
    FROM patients
    WHERE subject_id = %s
    """
    
    try:
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        cursor.execute(query, (subject_id,))
        result = cursor.fetchone()
        return dict(result) if result else None
    except Exception as e:
        st.warning(f"获取患者信息失败: {e}")
        return None
    finally:
        cursor.close()
        if conn:
            conn.close()

def insert_ventilator_action(subject_id, hadm_id, stay_id, action_params):
    """
    记录呼吸机参数调整（将由主系统调用）
    
    参数:
        subject_id: 患者ID
        hadm_id: 住院ID
        stay_id: ICU停留ID
        action_params: dict，包含peep, fio2, tidal_volume等
    """
    conn = get_db_connection()
    if not conn:
        return False
    
    insert_query = """
    INSERT INTO ventilator_actions 
    (subject_id, hadm_id, stay_id, charttime, peep, fio2, tidal_volume, rate_set, agent_decision)
    VALUES (%s, %s, %s, NOW(), %s, %s, %s, %s, %s)
    """
    
    try:
        cursor = conn.cursor()
        cursor.execute(insert_query, (
            subject_id,
            hadm_id,
            stay_id,
            action_params.get('peep'),
            action_params.get('fio2'),
            action_params.get('tidal_volume'),
            action_params.get('rate_set'),
            action_params.get('agent_decision', '{}')
        ))
        conn.commit()
        return True
    except Exception as e:
        st.error(f"记录参数失败: {e}")
        return False
    finally:
        cursor.close()
        if conn:
            conn.close()
